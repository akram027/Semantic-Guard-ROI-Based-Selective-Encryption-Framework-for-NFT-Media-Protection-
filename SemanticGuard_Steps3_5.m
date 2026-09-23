%% Semantic Guard: ROI Watermarking + Selective AES-256 Encryption
% Steps 3-5 of the proposed on-chain verification workflow
% Input files:
%   ROI Image(2).png
%   binary ground-truth ROI mask.bmp
%
% Output:
%   Step 3: Binary ROI mask exported/normalized for MATLAB
%   Step 4: DCT watermark embedded only in ROI
%   Step 5: AES-256-CTR encryption applied only to ROI bytes
%
% The script also decrypts the protected asset and verifies the watermark.
% MATLAB toolboxes: Image Processing Toolbox.
% For METHOD='DWT', Wavelet Toolbox is additionally required.

clear; close all; clc;

%% ------------------------- USER SETTINGS ------------------------------
IMAGE_FILE = 'ROI Image(2).png';
MASK_FILE  = 'binary ground-truth ROI mask.bmp';

METHOD = 'DCT';             % 'DCT' or 'DWT'
BLOCK_SIZE = 8;             % DCT block size
DWT_BLOCK_SIZE = 16;        % DWT block size
MIN_ROI_FRACTION = 0.90;    % block must be >=90% ROI
EMBED_STRENGTH = 6.0;       % DCT coefficient separation
WATERMARK_TEXT = 'SEMANTIC-GUARD-AKRAM';

PASSPHRASE = 'SemanticGuard-AES256-Demo';
OUTPUT_DIR = 'semantic_guard_matlab_results';
if ~exist(OUTPUT_DIR,'dir'), mkdir(OUTPUT_DIR); end

%% ---------------- STEP 3: IMPORT/EXPORT ROI MASK ---------------------
rgb = imread(IMAGE_FILE);
if size(rgb,3) > 3, rgb = rgb(:,:,1:3); end
rgb = im2uint8(rgb);

rawMask = imread(MASK_FILE);
if size(rawMask,3) > 1
    rawMask = rgb2gray(rawMask(:,:,1:3));
end
rawMask = im2uint8(rawMask);

% The supplied ground-truth BMP contains two grayscale levels.
% Dark pixels are ROI and light pixels are background.
roiMask = rawMask < 128;

% Safety check: if the mask is accidentally inverted, choose the
% interpretation with a plausible ROI area.
roiFraction = nnz(roiMask)/numel(roiMask);
if roiFraction > 0.80
    roiMask = ~roiMask;
    roiFraction = nnz(roiMask)/numel(roiMask);
end

% Match dimensions if necessary.
if ~isequal(size(roiMask), size(rgb(:,:,1)))
    roiMask = imresize(roiMask,[size(rgb,1) size(rgb,2)],'nearest');
end

imwrite(uint8(roiMask)*255, fullfile(OUTPUT_DIR,'ROI_Binary_Mask.png'));

figure('Name','Step 3 - ROI Binary Mask','Color','w');
subplot(1,2,1);
imshow(rgb); title('Original Media Asset');
subplot(1,2,2);
imshow(roiMask); title(sprintf('Binary ROI Mask (ROI = 1)\\nROI = %.2f%%', ...
    100*roiFraction));
exportgraphics(gcf,fullfile(OUTPUT_DIR,'Screenshot_Step3_ROI_Mask.png'), ...
    'Resolution',150);

%% ---------------- STEP 4: DCT/DWT WATERMARK ---------------------------
% Convert the image to luminance so the watermark is embedded in the
% perceptual intensity component rather than changing chroma.
ycbcr = rgb2ycbcr(rgb);
Y = double(ycbcr(:,:,1));

% Create a compact binary payload: 16-bit length + ASCII watermark.
wmBytes = uint8(WATERMARK_TEXT);
nBytes = numel(wmBytes);
header = uint8([bitshift(uint16(nBytes),-8), bitand(uint16(nBytes),255)]);
payloadBytes = [header wmBytes];
payloadBits = bytes_to_bits(payloadBytes);

switch upper(METHOD)
    case 'DCT'
        [Yw, usedBlocks] = embedDCT_ROI(Y,roiMask,payloadBits,...
            BLOCK_SIZE,MIN_ROI_FRACTION,EMBED_STRENGTH);

    case 'DWT'
        [Yw, usedBlocks] = embedDWT_ROI(Y,roiMask,payloadBits,...
            DWT_BLOCK_SIZE,MIN_ROI_FRACTION,EMBED_STRENGTH);

    otherwise
        error('METHOD must be DCT or DWT.');
end

ycbcrW = ycbcr;
ycbcrW(:,:,1) = uint8(min(max(round(Yw),0),255));
watermarkedRGB = ycbcr2rgb(ycbcrW);

% Quality measurements
psnrValue = psnr(watermarkedRGB,rgb);
ssimValue = ssim(watermarkedRGB,rgb);

imwrite(watermarkedRGB,fullfile(OUTPUT_DIR,'Watermarked_ROI_DCT.png'));

figure('Name','Step 4 - ROI Watermarking','Color','w');
subplot(1,3,1); imshow(rgb); title('Original');
subplot(1,3,2); imshow(watermarkedRGB);
title(sprintf('%s Watermarked in ROI',METHOD));
subplot(1,3,3);
difference = uint8(min(abs(double(watermarkedRGB)-double(rgb))*8,255));
imshow(difference);
title('8x Amplified Difference');
sgtitle(sprintf('PSNR = %.2f dB | SSIM = %.6f | Blocks = %d', ...
    psnrValue,ssimValue,numel(usedBlocks)/2));
exportgraphics(gcf,fullfile(OUTPUT_DIR,'Screenshot_Step4_Watermark.png'), ...
    'Resolution',150);

%% ---------------- STEP 5: SELECTIVE AES-256 ENCRYPTION ---------------
% Important design point:
% AES encrypts bytes, not individual pixels. Here only RGB bytes belonging
% to the ROI are encrypted. Non-ROI pixels remain unchanged.
%
% AES-CTR is used because it preserves the exact byte-stream length,
% allowing the encrypted ROI to be restored without padding.
% A fresh random IV is generated for each protected asset.

iv = uint8(randi([0 255],1,16));
key = sha256_key(PASSPHRASE);       % 32 bytes = AES-256

encryptedRGB = watermarkedRGB;
roiBytes = watermarkedRGB(repmat(roiMask,1,1,3));
roiBytes = uint8(roiBytes(:));

encryptedROIBytes = aes256_ctr(roiBytes,key,iv,true);
encryptedRGB(repmat(roiMask,1,1,3)) = encryptedROIBytes;

encryptedBytes = numel(encryptedROIBytes);
totalBytes = numel(watermarkedRGB);
encryptionPercentage = 100*encryptedBytes/totalBytes;

% Save a MATLAB container. Do not store the secret key in the file.
save(fullfile(OUTPUT_DIR,'Encrypted_Asset.mat'), ...
    'encryptedRGB','roiMask','iv','-v7.3');

% Also save a display-only preview. The encrypted array is NOT intended
% to be interpreted as a normal PNG/JPEG file.
imwrite(encryptedRGB,fullfile(OUTPUT_DIR,'Selective_AES256_Preview.png'));

figure('Name','Step 5 - Selective AES-256','Color','w');
subplot(1,3,1); imshow(watermarkedRGB);
title('Watermarked Asset');
subplot(1,3,2); imshow(encryptedRGB);
title('Selective AES-256 Preview');
subplot(1,3,3); imshow(roiMask);
title(sprintf('Encrypted ROI = %.2f%%',encryptionPercentage));
sgtitle('Only ROI RGB bytes are encrypted; background remains unchanged');
exportgraphics(gcf,fullfile(OUTPUT_DIR,'Screenshot_Step5_AES256.png'), ...
    'Resolution',150);

%% ---------------- AUTHORIZED DECRYPTION + WATERMARK VERIFICATION -----
% The owner/authorized verifier supplies the same passphrase and IV.
decryptedRGB = encryptedRGB;
encryptedROI = encryptedRGB(repmat(roiMask,1,1,3));
encryptedROI = uint8(encryptedROI(:));

decryptedROI = aes256_ctr(encryptedROI,key,iv,false);
decryptedRGB(repmat(roiMask,1,1,3)) = decryptedROI;

% Verify byte-exact recovery of the watermarked asset.
recoveryOK = isequal(decryptedRGB,watermarkedRGB);

% Extract the watermark from the decrypted image.
switch upper(METHOD)
    case 'DCT'
        extractedBits = extractDCT_ROI(double(rgb2ycbcr(decryptedRGB(:,:,1:3))),...
            roiMask,numel(payloadBits),BLOCK_SIZE,MIN_ROI_FRACTION);
    case 'DWT'
        extractedBits = extractDWT_ROI(double(rgb2ycbcr(decryptedRGB(:,:,1:3))),...
            roiMask,numel(payloadBits),DWT_BLOCK_SIZE,MIN_ROI_FRACTION);
end

extractedBytes = bits_to_bytes(extractedBits);
decodedLength = double(extractedBytes(1))*256 + double(extractedBytes(2));

if decodedLength <= numel(extractedBytes)-2
    recoveredWatermark = char(extractedBytes(3:2+decodedLength));
else
    recoveredWatermark = 'Extraction failed';
end

watermarkOK = strcmp(recoveredWatermark,WATERMARK_TEXT);

figure('Name','Verification','Color','w');
imshow(decryptedRGB);
title({sprintf('Authorized Decryption: %s',string(recoveryOK)), ...
       sprintf('Recovered Watermark: %s',recoveredWatermark), ...
       sprintf('Watermark Verification: %s',string(watermarkOK))});
exportgraphics(gcf,fullfile(OUTPUT_DIR,'Screenshot_Verification.png'), ...
    'Resolution',150);

%% ---------------- EXPERIMENT SUMMARY ---------------------------------
fprintf('\n============================================================\n');
fprintf('SEMANTIC GUARD - MATLAB STEPS 3-5\n');
fprintf('============================================================\n');
fprintf('Image size                 : %d x %d x 3\n',size(rgb,1),size(rgb,2));
fprintf('ROI pixels                 : %d (%.2f%%)\n',nnz(roiMask),100*roiFraction);
fprintf('Watermark method           : %s\n',METHOD);
fprintf('Watermark                  : %s\n',WATERMARK_TEXT);
fprintf('Watermark payload          : %d bits\n',numel(payloadBits));
fprintf('PSNR after watermark       : %.2f dB\n',psnrValue);
fprintf('SSIM after watermark       : %.6f\n',ssimValue);
fprintf('Total RGB bytes            : %d\n',totalBytes);
fprintf('AES-encrypted ROI bytes    : %d\n',encryptedBytes);
fprintf('Selective encryption ratio : %.2f%%\n',encryptionPercentage);
fprintf('Decryption byte recovery   : %s\n',string(recoveryOK));
fprintf('Watermark verification     : %s\n',string(watermarkOK));
fprintf('Results folder             : %s\n',OUTPUT_DIR);
fprintf('============================================================\n');

%% =========================== LOCAL FUNCTIONS ==========================

function bits = bytes_to_bits(bytes)
    bytes = uint8(bytes(:));
    bits = zeros(1,8*numel(bytes),'uint8');
    for k=1:numel(bytes)
        b = dec2bin(bytes(k),8)-'0';
        bits(8*k-7:8*k) = uint8(b);
    end
end

function bytes = bits_to_bytes(bits)
    bits = uint8(bits(:).');
    n = floor(numel(bits)/8);
    bytes = zeros(1,n,'uint8');
    for k=1:n
        bytes(k) = uint8(bin2dec(char(bits(8*k-7:8*k)+'0')));
    end
end

function [Yw,used] = embedDCT_ROI(Y,mask,bits,B,minFrac,strength)
    [H,W] = size(Y);
    Yw = Y;
    used = [];
    bitIndex = 1;

    for r=1:B:(H-B+1)
        for c=1:B:(W-B+1)
            if mean(mask(r:r+B-1,c:c+B-1),'all') >= minFrac
                if bitIndex > numel(bits), return; end
                C = dct2(Y(r:r+B-1,c:c+B-1));
                a = C(3,4); b = C(4,3);
                d = a-b;
                target = strength;
                if bits(bitIndex)==1
                    if d < target
                        delta=(target-d)/2;
                        C(3,4)=C(3,4)+delta;
                        C(4,3)=C(4,3)-delta;
                    end
                else
                    target=-strength;
                    if d > target
                        delta=(d-target)/2;
                        C(3,4)=C(3,4)-delta;
                        C(4,3)=C(4,3)+delta;
                    end
                end
                Yw(r:r+B-1,c:c+B-1)=idct2(C);
                used=[used;r c]; %#ok<AGROW>
                bitIndex=bitIndex+1;
            end
        end
    end

    if bitIndex <= numel(bits)
        error('Not enough ROI blocks for the watermark payload.');
    end
end

function bits = extractDCT_ROI(Y3,mask,nBits,B,minFrac)
    Y = Y3(:,:,1);
    [H,W]=size(Y);
    bits=zeros(1,nBits,'uint8');
    k=1;
    for r=1:B:(H-B+1)
        for c=1:B:(W-B+1)
            if mean(mask(r:r+B-1,c:c+B-1),'all') >= minFrac
                if k>nBits, return; end
                C=dct2(Y(r:r+B-1,c:c+B-1));
                bits(k)=uint8(C(3,4)>=C(4,3));
                k=k+1;
            end
        end
    end
end

function [Yw,used] = embedDWT_ROI(Y,mask,bits,B,minFrac,strength)
    [H,W]=size(Y);
    Yw=Y; used=[]; k=1;
    for r=1:B:(H-B+1)
        for c=1:B:(W-B+1)
            if mean(mask(r:r+B-1,c:c+B-1),'all')>=minFrac
                if k>numel(bits), return; end
                [LL,LH,HL,HH]=dwt2(Y(r:r+B-1,c:c+B-1),'haar');
                a=LH(2,2); b=HL(2,2); d=a-b;
                target = strength*(2*bits(k)-1);
                if (bits(k)==1 && d<target) || (bits(k)==0 && d>target)
                    delta=(target-d)/2;
                    LH(2,2)=LH(2,2)+delta;
                    HL(2,2)=HL(2,2)-delta;
                end
                Yw(r:r+B-1,c:c+B-1)=idwt2(LL,LH,HL,HH,'haar');
                used=[used;r c]; %#ok<AGROW>
                k=k+1;
            end
        end
    end
    if k<=numel(bits), error('Not enough ROI blocks for DWT watermark.'); end
end

function bits = extractDWT_ROI(Y3,mask,nBits,B,minFrac)
    Y=Y3(:,:,1); [H,W]=size(Y);
    bits=zeros(1,nBits,'uint8'); k=1;
    for r=1:B:(H-B+1)
        for c=1:B:(W-B+1)
            if mean(mask(r:r+B-1,c:c+B-1),'all')>=minFrac
                if k>nBits, return; end
                [~,LH,HL,~]=dwt2(Y(r:r+B-1,c:c+B-1),'haar');
                bits(k)=uint8(LH(2,2)>=HL(2,2));
                k=k+1;
            end
        end
    end
end

function key = sha256_key(passphrase)
    md = java.security.MessageDigest.getInstance('SHA-256');
    digest = md.digest(uint8(passphrase));
    key = typecast(digest,'uint8');
    key = key(:).';
end

function out = aes256_ctr(in,key,iv,encryptMode)
    import javax.crypto.Cipher
    import javax.crypto.spec.SecretKeySpec
    import javax.crypto.spec.IvParameterSpec

    cipher = Cipher.getInstance('AES/CTR/NoPadding');
    ks = SecretKeySpec(typecast(uint8(key),'int8'),'AES');
    ivs = IvParameterSpec(typecast(uint8(iv),'int8'));

    if encryptMode
        cipher.init(Cipher.ENCRYPT_MODE,ks,ivs);
    else
        cipher.init(Cipher.DECRYPT_MODE,ks,ivs);
    end

    javaIn = typecast(uint8(in(:)),'int8');
    javaOut = cipher.doFinal(javaIn);
    out = typecast(javaOut,'uint8');
    out = out(:);
end
