//
// mnml
// Copyright © 2026 CreativityKills
// SPDX-License-Identifier: MIT
//

import AVFoundation
import Accelerate
import MediaToolbox
import os

/// Installs an `MTAudioProcessingTap` on a player item's audio track and computes a
/// per-buffer RMS (loudness) into a thread-safe store. The real-time `process`
/// callback does a single `vDSP` mean-square pass and one guarded write — no
/// allocations, no blocking. Read the latest value from the main actor via
/// `currentLevel()`.
final class AudioLevelTap {
    /// Lock-guarded holder shared with the C callbacks. A class so it can be passed as
    /// an opaque pointer and retained across the tap's lifetime.
    final class Storage {
        private var lock = os_unfair_lock()
        private var value: Float = 0

        func read() -> Float {
            os_unfair_lock_lock(&lock)
            defer { os_unfair_lock_unlock(&lock) }
            return value
        }
        func write(_ newValue: Float) {
            os_unfair_lock_lock(&lock)
            value = newValue
            os_unfair_lock_unlock(&lock)
        }
    }

    private let storage = Storage()

    /// Latest RMS (≈0…1). 0 when no audio is flowing (paused, remote route, not yet warm).
    func currentLevel() -> Float { storage.read() }

    /// Forces the level back to rest — call on teardown so a stale value doesn't linger.
    func reset() { storage.write(0) }

    /// Builds an audio mix carrying the metering tap for `item`'s first audio track.
    /// Returns nil if the asset exposes no audio track; the caller then leaves the
    /// item's `audioMix` unset and the meter simply reads 0 (calm baseline).
    func makeAudioMix(for item: AVPlayerItem) async -> AVAudioMix? {
        // The caller attaches the returned mix from a detached Task, so the prepare
        // path itself stays synchronous.
        guard let track = try? await item.asset.loadTracks(withMediaType: .audio).first else {
            return nil
        }

        // The callbacks are literal closures (not named-function references) so Swift infers
        // each parameter's exact imported type — including pointer optionality — from the
        // MTAudioProcessingTapCallbacks initializer. They capture nothing (only their own
        // parameters and file-scope symbols), so they remain valid C function pointers.
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: UnsafeMutableRawPointer(Unmanaged.passRetained(storage).toOpaque()),
            init: { _, clientInfo, tapStorageOut in
                // Carry the Storage pointer (clientInfo) into per-tap storage so later
                // callbacks can reach it via MTAudioProcessingTapGetStorage.
                tapStorageOut.pointee = clientInfo
            },
            finalize: { tap in
                // Balance the passRetained(storage) below: release exactly once on teardown.
                Unmanaged<AudioLevelTap.Storage>
                    .fromOpaque(MTAudioProcessingTapGetStorage(tap))
                    .release()
            },
            prepare: nil,
            unprepare: nil,
            process: { tap, numberFrames, _, bufferListInOut, numberFramesOut, flagsOut in
                // Real-time: pull the source audio, compute RMS across all channels, store it.
                // No allocations, no locks beyond the single guarded write inside Storage.write.
                let status = MTAudioProcessingTapGetSourceAudio(
                    tap, numberFrames, bufferListInOut, flagsOut, nil, numberFramesOut)
                guard status == noErr else { return }

                let storage = Unmanaged<AudioLevelTap.Storage>
                    .fromOpaque(MTAudioProcessingTapGetStorage(tap))
                    .takeUnretainedValue()

                // AAC decoded by AVPlayer is delivered as 32-bit float PCM. Sum mean-squares
                // across channels weighted by sample count, then take the overall RMS.
                let buffers = UnsafeMutableAudioBufferListPointer(bufferListInOut)
                var weightedMeanSquares: Float = 0
                var totalSamples = 0
                for buffer in buffers {
                    guard let data = buffer.mData else { continue }
                    let n = Int(buffer.mDataByteSize) / MemoryLayout<Float>.size
                    guard n > 0 else { continue }
                    let samples = data.assumingMemoryBound(to: Float.self)
                    var meanSquare: Float = 0
                    vDSP_measqv(samples, 1, &meanSquare, vDSP_Length(n))  // (Σ xᵢ²) / n
                    weightedMeanSquares += meanSquare * Float(n)
                    totalSamples += n
                }
                guard totalSamples > 0 else { return }
                storage.write(sqrt(weightedMeanSquares / Float(totalSamples)))
            }
        )

        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault, &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects, &tap)
        guard status == noErr, let created = tap else {
            // Creation failed: balance the passRetained above so Storage isn't leaked.
            Unmanaged<Storage>.fromOpaque(callbacks.clientInfo!).release()
            return nil
        }

        let params = AVMutableAudioMixInputParameters(track: track)
        params.audioTapProcessor = created
        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        return mix
    }
}
