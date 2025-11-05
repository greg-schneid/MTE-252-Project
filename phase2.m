% Author: Greg Schneider, Abhay Ratti

function plot_min_max_signals(signals, name)
    % Plot Signals of Lowest and Highest Frequency Bands
    figure('Name', name);
    
    % Create time vector for x-axis
    time1 = (0:length(signals{1})-1) / 16000;
    timeN = (0:length(signals{length(signals)})-1) / 16000;
    
    % Work out Frequency range for both signals
    n = length(signals);
    low_freq = 100; % Hz
    hi_freq = 8000; % Hz
    freq_step = (hi_freq - low_freq) / n;

    freq0 = [low_freq, low_freq + freq_step];
    freqn = [low_freq + freq_step*(n-1), low_freq + freq_step*n];

    subplot(1,2,1);
    plot(time1, signals{1});
    title(sprintf('Lowest Frequency Band Signal (%.1f Hz - %.1f Hz)', freq0(1), freq0(2)));
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;
    subplot(1,2,2);
    plot(timeN, signals{length(signals)});
    title(sprintf('Highest Frequency Band Signal (%.1f Hz - %.1f Hz)', freqn(1), freqn(2)));
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;
    
    % Add overall title to the figure
    sgtitle(name);
end

function split_signals = split_frequency(n, signal)
    split_signals = cell (1,n);
    low_freq = 100; % Hz
    hi_freq = 8000; % Hz
    freq_step = (hi_freq - low_freq) / n;
    for i = 1:n
        band_low = low_freq + (i-1) * freq_step;
        band_high = low_freq + i * freq_step;
        split_signals{i} = bandpass(signal, [band_low, band_high], 16000);
    end

    plot_min_max_signals(split_signals, 'Signals of Lowest and Highest Frequency Bands');
end

%Tasks 
function processed_signals = envelope_extraction(signals)
    processed_signals = cell(size(signals));
    for i = 1:length(signals)
        % Lowpass filter has a cutoff frequency of 400 Hz, and sample rate of 16 kHz
        % Outer Abs included since sometimes lowpass can produce small negative values
        processed_signals{i} = abs(lowpass(abs(signals{i}), 400, 16000)); % Rectification & Lowpass Filtering
    end
    plot_min_max_signals(processed_signals, 'Envelope Extracted Signals of Lowest and Highest Frequency Bands');
end


% Main Execution
signals = split_frequency(16, audioread('Dataset/processed/siren_mono_16k.wav'));
processed_signals = envelope_extraction(signals);