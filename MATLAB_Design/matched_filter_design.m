% Generates chirp → noise → decimate → matched-filter (normalized) → plot →
% export coeff + input as 16-bit binary for Verilog $readmemb.

clear; clc; close all;

%% 1) Parameters ------------------------------------------------------------
Fs     = 5e6;                % sample rate [Hz]
T      = 1e-3;               % pulse length [s]
B      = 100e3;              % bandwidth [Hz]
D      = 20;                 % decimation factor
Fs_dec = Fs/D;               % decimated rate
t      = (0:1/Fs:T-1/Fs).';  % column vector

SNRdB  = -5;                 % input SNR

%% 2) Create chirp + noise -------------------------------------------------
k   = B/T;
phi = 2*pi*(-B/2*t + 0.5*k*t.^2);
s   = exp(1j*phi);
Px  = mean(abs(s).^2);
Pn  = Px/10^(SNRdB/10);
r   = s + sqrt(Pn/2)*(randn(size(s))+1j*randn(size(s)));

%% 3) Decimate --------------------------------------------------------------
s_dec = downsample(s, D);     % ~250 samples
r_dec = downsample(r, D);

%% 4) Build & apply **normalized** matched filter -------------------------
N     = numel(s_dec);
h_dec = conj(flipud(s_dec))/N; % normalize by length
y_dec = conv(r_dec, h_dec);
mag_y = abs(y_dec);

%% 5) SNR check & plots ----------------------------------------------------
in_snr  = 10*log10(Px/Pn) - 10*log10(D);
out_snr = 10*log10(max(mag_y)^2/var(mag_y));
fprintf('Input SNR (decimated) ≈ %.1f dB,  Output ≈ %.1f dB\n', in_snr, out_snr);

figure;
subplot(3,1,1);
plot((0:N-1)/Fs_dec*1e3, real(r_dec)); grid on;
title('Decimated received (real)'); xlabel('ms');

subplot(3,1,2);
plot((0:numel(y_dec)-1)/Fs_dec*1e3, real(y_dec)); grid on;
title('Matched-filter output (real)'); xlabel('ms');

subplot(3,1,3);
plot((0:numel(mag_y)-1)/Fs_dec*1e3, mag_y); grid on;
title('Matched-filter magnitude'); xlabel('ms');

%% 6) Export binary-text for Verilog $readmemb -----------------------------
FS      = 2^15-1;
minInt  = -2^15;
maxInt  =  2^15-1;

% --- a) coeffs at full Q15 (normalized) ---
h_re_i = int16(round(real(h_dec)*FS));
h_im_i = int16(round(imag(h_dec)*FS));
h_re_i = max(min(h_re_i,int16(maxInt)),int16(minInt));
h_im_i = max(min(h_im_i,int16(maxInt)),int16(minInt));
h_re_u = typecast(h_re_i,'uint16');
h_im_u = typecast(h_im_i,'uint16');

% --- b) auto-scale receive to 90% FS ---
allRe  = real(r_dec(:));
allIm  = imag(r_dec(:));
pk     = max([abs(allRe);abs(allIm)]);
scale  = (FS/pk)*0.9;
fprintf('Auto-scale factor = %.3f (raw peak=%.3f)\n', scale, pk);

r_re_i = int16(round(allRe*scale));
r_im_i = int16(round(allIm*scale));
r_re_i = max(min(r_re_i,int16(maxInt)),int16(minInt));
r_im_i = max(min(r_im_i,int16(maxInt)),int16(minInt));
r_re_u = typecast(r_re_i,'uint16');
r_im_u = typecast(r_im_i,'uint16');

% --- c) write files ---
f_cr = fopen('coeff_real_bin.txt','w');
f_ci = fopen('coeff_imag_bin.txt','w');
f_rr = fopen('input_real_bin.txt','w');
f_ri = fopen('input_imag_bin.txt','w');

for k = 1:N
    fprintf(f_cr, '%s\n', dec2bin(h_re_u(k),16));
    fprintf(f_ci, '%s\n', dec2bin(h_im_u(k),16));
end
for k = 1:N
    fprintf(f_rr, '%s\n', dec2bin(r_re_u(k),16));
    fprintf(f_ri, '%s\n', dec2bin(r_im_u(k),16));
end

fclose(f_cr); fclose(f_ci);
fclose(f_rr); fclose(f_ri);

fprintf('Exported %d taps and %d samples.\n', N, N);
