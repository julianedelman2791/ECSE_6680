% plot_sim_io.m
data    = load('sim_io.txt');   % columns: cycle in_r in_i out_r out_i
cycle   = data(:,1);
in_r    = data(:,2);
in_i    = data(:,3);
out_r   = data(:,4);
out_i   = data(:,5);

out_mag = sqrt(double(out_r).^2 + double(out_i).^2);

figure;
subplot(3,1,1)
plot(cycle, in_r);
title('Input Real (Q15)'); xlabel('Cycle'); ylabel('Amplitude');

subplot(3,1,2)
plot(cycle, out_r);
title('Output Real (Q15)'); xlabel('Cycle'); ylabel('Amplitude');

subplot(3,1,3)
plot(cycle, out_mag);
title('Matched-Filter Output Magnitude'); 
xlabel('Cycle'); ylabel('|y[n]|');
