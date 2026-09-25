# G: Offline speech-to-text options (Windows speech not needed), 2026-09-24

Scope: local/offline, English only. Reason: Windows' own speech recognition (Win+H and Unity
`DictationRecognizer`, which Unity documents as Windows-10-only and gated by the Windows speech
privacy setting) gives no output on the user's machine, even though the mic works and the speech
language is English.
All sources below were fetched in full on 2026-09-24. Raw copies are in the session scratchpad.

## 1. Engines

| | Vosk | sherpa-onnx | Whisper.net (whisper.cpp) |
|---|---|---|---|
| NuGet | `Vosk` 0.3.38 | `org.k2fsa.sherpa.onnx` 1.13.8 | `Whisper.net` 1.9.1 |
| Last updated | 2022-05-24 | 2026-09-11 | 2026-06-01 |
| License | Apache-2.0 | Apache-2.0 | MIT |
| Targets | netstandard2.0; computed net461–481 | netstandard2.0; net20/35/40/45; net6+ | netstandard2.0; net8+ |
| Extra deps | none listed | per-platform runtime pkgs (win-x64 …) | Bcl.AsyncInterfaces, System.Memory; VC++ 2022 redist |
| Unity | official page: "Unity is essentially C#/Mono scripting environment", sample repo `alphacep/vosk-unity-asr` | not mentioned in docs read | not mentioned in README |

## 2. English models: size and streaming

Vosk (alphacephei.com/vosk/models). "small models … around 50MB … approximately 300MB runtime
memory", big models "up to 16GB". Vosk describes itself as "Provides streaming API".

| Model | Size | WER as published |
|---|---|---|
| vosk-model-small-en-us-0.15 | 40M | 9.85 librispeech test-clean, 10.38 tedlium |
| vosk-model-en-us-0.22-lgraph | 128M | 7.82 librispeech, 8.20 tedlium |
| vosk-model-en-us-0.22 | 1.8G | 5.69 / 6.05 / 29.78 callcenter |
| vosk-model-en-us-0.42-gigaspeech | 2.3G | 5.64 / 6.24 / 30.17 callcenter |

sherpa-onnx streaming zipformer (true streaming, `OnlineRecognizer`), from the sherpa docs' `ls -lh`
listings. Size = encoder + decoder + joiner. The docs list no WER for these models.

| Model | Training data | fp32 | int8 |
|---|---|---|---|
| streaming-zipformer-en-20M-2023-02-17 ("It is a small model") | LibriSpeech | 85M+2.0M+1.0M ≈ 88M | 41M+527K+253K ≈ 42M |
| streaming-zipformer-en-2023-06-26 | LibriSpeech | 250M+2.0M+1003K ≈ 253M | 68M+1.3M+254K ≈ 70M |
| streaming-zipformer-en-2023-06-21 | LibriSpeech + GigaSpeech | 337M+2.0M+1.0M ≈ 340M | 179M+1.2M+253K ≈ 181M |
| streaming-zipformer-en-2023-02-21 | LibriSpeech | 338M+2.0M+1003K ≈ 341M | 180M+1.3M+254K ≈ 182M |

sherpa-onnx Moonshine (a non-streaming model; the docs call their microphone mode "simulated
streaming" with VAD): `moonshine-base-en-quantized-2026-02-27` is 135M total (decoder 105M, encoder
30M). The docs' sample run gives "Real time factor (RTF): 0.419 / 3.845 = 0.109" with 2 threads.
The same set includes a Korean model, `moonshine-tiny-ko-quantized-2026-02-27` (not sized).

whisper.cpp (README "Memory usage"): tiny 75 MiB disk / ~273 MB mem; base 142 MiB / ~388 MB; small
466 MiB / ~852 MB; medium 1.5 GiB / ~2.1 GB; large 2.9 GiB / ~3.9 GB. Streaming: the README
calls `whisper-stream` "a naive example of performing real-time inference" that "samples the audio
every half a second and runs the transcription continuously". Whisper.net's README has no
streaming or real-time API; it processes a file or stream (`processor.ProcessAsync(fileStream)`).

## 3. Noise benchmarks with stated noise type and level (direct quotes)

**Whisper paper, arXiv:2212.04356, §3.7 and Figure 5.**
- "measuring the WER when either white noise or pub noise from the Audio Degradation Toolbox
  (Mauch & Ewert, 2013) was added to the audio. The pub noise represents a more natural noisy
  environment with ambient noise and indistinct chatter typical in a crowded restaurant or a pub."
- "The level of additive noise corresponding to a given signal-to-noise ratio (SNR) is calculated
  based on the signal power of individual examples." The x-axis runs 40 → −10 dB SNR, on
  LibriSpeech test-clean.
- "all models quickly degrade as the noise becomes more intensive, performing worse than the
  Whisper model under additive pub noise of SNR below 10 dB."
- Figure 5 caption: "The accuracy of LibriSpeech-trained models degrade faster than the best Whisper
  model (⋆). NVIDIA STT models (•) perform best under low noise but are outperformed by Whisper
  under high noise (SNR < 10 dB)."
- Caveats: the values exist only as a plot (not extracted). The Whisper point is "the best Whisper
  model", not tiny or base. Vosk and zipformer models were not among the 14 tested.

**Moonshine paper, arXiv:2410.15608, §4.3 and Figure 6.**
- "measuring the WER for the fan noise observed in a tablet computer application under load. In
  user studies, we quantified the signal-to-noise ratio (SNR) for this application in the range
  [9, 17] dB depending on the speaker."
- "We calculate the level of additive noise corresponding to a given SNR based on the average
  signal power of individual dataset examples with quiet sections removed."
- Figure 6 caption: "WER as signal-to-noise ratio increases under additive computer fan noise.
  Moonshine degrades similarly to OpenAI's Whisper counterpart while maintaining superior WER
  values." The comparison is Moonshine Base vs Whisper base.en, SNR axis 0–30 dB, on LibriSpeech
  test-clean. Values are plot-only.
- §4.2, input level: "where gain is below -40 dB, i.e., the input audio is very quiet) the WER
  rises above the Whisper model."
- Clean WER, Table 2 (Whisper base.en / Moonshine Base): LibriSpeech clean 4.25 / 3.23, other
  10.35 / 8.18, AMI 21.13 / 17.79, average 10.32 / 10.07. Table 3 (tiny.en / Moonshine Tiny):
  LibriSpeech clean 5.66 / 4.52, other 15.45 / 11.71, average 12.81 / 12.66.

**Vosk and sherpa zipformer:** no noise benchmark with a stated noise type or level was found.
Searched: the arXiv API for zipformer+noise, the Vosk accuracy page, and the sherpa model page.
Vosk's accuracy page gives only qualitative causes ("Audio has very bad quality", accent mismatch).

## 4. Typical use environments (as stated by the sources)

- **Vosk.** From the integrations page, telephony: Asterisk, FreeSWITCH, Jigasi, UniMRCP, the
  "AI voicebots for telephony" platform AVR, and call analytics. Also robotics (ROS, draft),
  subtitle generation (kdenlive, Subtitle Edit, TUM-Live), desktop dictation (nerd-dictation, IBus),
  and offline assistants and smart speakers on Raspberry Pi. Model notes: small-en "Lightweight
  wideband model for Android and RPi"; gigaspeech "Mostly for podcasts, not for telephony".
- **Moonshine.** Stated applications: "live transcription during presentations, accessibility tools
  for individuals with hearing impairments, and voice command processing for conversational
  interfaces in smart devices and wearables"; built for "a Caption Box … private offline
  transcription of English speech".
- **sherpa-onnx.** Documented platforms: desktop (Win/Linux/macOS), Android/iOS/HarmonyOS,
  embedded (ARM, RISC-V, Jetson), WebAssembly, and NPUs (Qualcomm QNN, rknn, Ascend). The pages
  read contain no use-case statements.
- **Whisper (paper).** Evaluated for robustness across datasets and long-form transcription. Per
  the Moonshine paper, tiny.en has "a firm lower latency bound of 500 milliseconds" on a low-cost
  ARM processor because of 30-second zero-padding.

## 4b. Size vs accuracy (streaming English models only; Moonshine dropped by user 2026-09-24)

Source for sherpa WERs: icefall `egs/librispeech/ASR/RESULTS.md` (master, fetched 2026-09-24).
The sherpa → icefall mapping comes from the sherpa page's "converted from" links. Rows use greedy
search with a 320 ms chunk, chunk-wise (real streaming) where published. All numbers are % WER on
LibriSpeech (clean read audiobooks, no added noise).

| Model | Params | Download (int8) | test-clean | test-other | Notes |
|---|---|---|---|---|---|
| sherpa en-20M-2023-02-17 | "~20M" | ≈42M | 3.94 | 9.79 | simulated streaming (chunk-wise not published) |
| sherpa en-2023-06-26 | 66.11 M | ≈70M | 3.06 | 7.79 | chunk-wise |
| sherpa en-2023-02-21 | 70.37 M | ≈182M | 3.17 | 8.24 | chunk-wise |
| sherpa en-2023-06-21 (Libri+GigaSpeech) | 70.37 M | ≈181M | 2.47 | 6.13 | chunk-wise; GigaSpeech test 11.98 (sim.) |
| vosk small-en-us-0.15 | — | 40M | 9.85 | — | tedlium 10.38 |
| vosk en-us-0.22-lgraph | — | 128M | 7.82 | — | tedlium 8.20 |
| vosk en-us-0.22 | — | 1.8G | 5.69 | — | tedlium 6.05 |
| vosk en-us-0.42-gigaspeech | — | 2.3G | 5.64 | — | tedlium 6.24 |

Also in RESULTS.md: chunk 640 ms gives lower WER than 320 ms for the same model (e.g. 06-26 greedy:
3.06/7.79 at 320 ms vs 2.84/7.16 at 640 ms chunk-wise).

## 5. Still unverified (needs a spike)

1. Whether native DLLs in the mod folder load under RimWorld's Mono P/Invoke.
2. The `UnityEngine.Microphone` API in RimWorld's Unity build (only a string grep so far), or the
   shipped `NAudio.dll`.
3. CPU cost while the game runs.
4. Vosk 0.3.38's native win-x64 packaging.
