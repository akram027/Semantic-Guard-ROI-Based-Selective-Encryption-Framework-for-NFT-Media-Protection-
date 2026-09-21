# Semantic-Guard-ROI-Based-Selective-Encryption-Framework-for-NFT-Media-Protection-
What the notebook validates
| Research stage           | Colab implementation                                                | Main result                   |
| ------------------------ | ------------------------------------------------------------------- | ----------------------------- |
| NFT/media acquisition    | Image upload + optional IPFS URL                                    | Input media                   |
| Preprocessing            | RGB, resizing/model preprocessing, normalization, tensor conversion | Preprocessed tensor           |
| Mask R-CNN               | ResNet-50 FPN, COCO pretrained model, threshold = 0.70              | Objects + masks               |
| ViT                      | ViT-Base/Patch-16 attention                                         | Attention map                 |
| Fusion                   | Mask R-CNN × normalized ViT attention                               | Fused ROI                     |
| Binary ROI               | Thresholding + noise removal                                        | Binary ROI mask               |
| ROI extraction           | ROI/background separation                                           | Extracted ROI                 |
| Segmentation evaluation  | Independent ground truth                                            | IoU, mIoU, Dice               |
| Selective encryption     | AES-256 on ROI                                                      | Encrypted image + timing      |
| Full encryption baseline | AES-256 on complete image                                           | Comparison baseline           |
| Watermarking             | DCT mid-frequency embedding                                         | Watermarked image             |
| Visual quality           | PSNR + SSIM                                                         | Imperceptibility measurements |
| Robustness               | JPEG + median filtering                                             | Watermark recovery            |
| Hybrid compression       | High compression outside ROI                                        | File-size/quality comparison  |
| Efficiency               | ROI ratio + timing + analytical model                               | Computational reduction       |
| IPFS                     | Content-addressing simulation                                       | CID/hash                      |
| Blockchain               | NFT metadata/integrity simulation                                   | Metadata hash                 |
| Ethereum                 | Optional real testnet integration                                   | Transaction support           |
| Final results            | CSV + TXT report                                                    | Manuscript-ready measurements |
