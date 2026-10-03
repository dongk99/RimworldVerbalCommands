# Model weights (not included in this repo)

This mod uses the `sherpa-onnx-streaming-zipformer-en-2023-06-21` streaming ASR model from
[k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx). The int8-quantized `.onnx` weight
files are excluded from this repository because the encoder alone is ~188 MB, and GitHub rejects
files over 100 MB.

Download the release archive:

```
https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/sherpa-onnx-streaming-zipformer-en-2023-06-21.tar.bz2
```

Extract it and copy the following three files into this folder
(`mod/Models/sherpa-onnx-streaming-zipformer-en-2023-06-21/`), alongside the `tokens.txt` and
`README.md` already present here:

| File | Size (bytes) | SHA256 |
|---|---|---|
| `decoder-epoch-99-avg-1.int8.onnx` | 539246 | `093e23c90869898f761f60aa3363f96d43b9c6e5c06a57860c3a5b3407ab8320` |
| `encoder-epoch-99-avg-1.int8.onnx` | 187823992 | `32c98281c7bd8b63e3e142d007251b37f120572e8fdea9a4f5a79ce22b10ec4f` |
| `joiner-epoch-99-avg-1.int8.onnx` | 259335 | `831477d390e59a61f1b6a6f763b9903e6c6366ff6034f1ddba613be82637122f` |

Verify with `sha256sum <file>` (Linux/macOS) or `Get-FileHash <file> -Algorithm SHA256`
(PowerShell) after copying.
