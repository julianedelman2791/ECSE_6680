%% compare_sim_vs_matlab_aligned.m
clear; clc; close all;

%% User parameters
Fs    = 5e6;       % original sample rate
T     = 1e-3;      % chirp duration
B     = 100e3;     % chirp bandwidth
D     = 20;        % decimation factor
SNRdB = -5;        % input SNR
Fs_dec = Fs/D;

%% 1) Recompute reference matched-filter metric --------------------------
% time vector
t   = (0:1/Fs:T-1/Fs).';
k   = B/T;
phi = 2*pi * (-B/2*t + 0.5*k*t.^2);
s   = exp(1j*phi);

% add noise & decimate
Px  = mean(abs(s).^2);
Pn  = Px/10^(SNRdB/10);
r   = s + sqrt(Pn/2)*(randn(size(s)) + 1j*randn(size(s)));
r_dec = downsample(r, D);

% build normalized taps (if you normalized in export)
h_dec = conj(flipud(downsample(s,D))) / numel(downsample(s,D));

% ideal matched-filter
y_ref = conv(r_dec, h_dec);
metric_ref = abs(y_ref);

%% 2) Load simulated I/O from sim_io.txt ---------------------------------
data = load('sim_io.txt');  
% columns: [cycle in_real in_imag out_real out_imag]
sim_out_real = data(:,4);
sim_out_imag = data(:,5);
metric_sim   = sqrt(double(sim_out_real).^2 + double(sim_out_imag).^2);

%% 3) Truncate to same length --------------------------------------------
Nref = numel(metric_ref);
Nsim = numel(metric_sim);
N    = min(Nref, Nsim);
metric_ref = metric_ref(1:N);
metric_sim = metric_sim(1:N);

%% 4) Compute raw (unaligned) error metrics -------------------------------
rmse_raw = sqrt(mean((metric_ref - metric_sim).^2));
R_raw    = corr(metric_ref, metric_sim);

fprintf('RAW comparison over %d samples:\n', N);
fprintf('  RMSE      = %.4f\n', rmse_raw);
fprintf('  Pearson R = %.4f\n\n', R_raw);

%% 5) Find best lag via cross-correlation ---------------------------------
% xcorr returns lags from -(N-1):(N-1)
[c, lags] = xcorr(metric_sim, metric_ref, 'coeff');
[~, idx]  = max(c);
best_lag  = lags(idx);

fprintf('Best circular lag = %+d samples\n\n', best_lag);

%% 6) Align sim -> ref by that lag -----------------------------------------
if best_lag > 0
    % sim leads ref: shift sim right, pad front
    metric_sim_al = [metric_sim(best_lag+1:end); metric_sim(1:best_lag)];
elseif best_lag < 0
    % sim lags ref: shift sim left, pad end
    shift = -best_lag;
    metric_sim_al = [metric_sim(end-shift+1:end); metric_sim(1:end-shift)];
else
    metric_sim_al = metric_sim;
end

%% 7) Compute aligned error metrics ---------------------------------------
rmse_al = sqrt(mean((metric_ref - metric_sim_al).^2));
R_al    = corr(metric_ref, metric_sim_al);

fprintf('ALIGNED comparison over %d samples:\n', N);
fprintf('  RMSE      = %.4f\n', rmse_al);
fprintf('  Pearson R = %.4f\n\n', R_al);

%% 8) Plot results --------------------------------------------------------
figure('Position',[200 200 800 600]);

subplot(3,1,1);
plot(0:N-1, metric_ref, '-b', 'DisplayName','MATLAB ref'); hold on;
plot(0:N-1, metric_sim, '--r', 'DisplayName','ModelSim raw');
xlabel('Sample index'); ylabel('|y[n]|');
title('Raw (unaligned) Matched-Filter Outputs');
legend('Location','best'); grid on;

subplot(3,1,2);
plot(0:N-1, metric_ref, '-b', 'DisplayName','MATLAB ref'); hold on;
plot(0:N-1, metric_sim_al, '--g', 'DisplayName','ModelSim aligned');
xlabel('Sample index'); ylabel('|y[n]|');
title('Aligned Matched-Filter Outputs');
legend('Location','best'); grid on;

subplot(3,1,3);
plot(0:N-1, metric_sim_al - metric_ref, '-k');
xlabel('Sample index'); ylabel('Error');
title('Pointwise Error (aligned)'); grid on;
