function plot_min_max_signals(signals, name)
    % Plot Signals of Lowest and Highest Frequency Bands
    figure('Name', name);
    
    % Create time vector for x-axis
    time1 = (0:length(signals{1})-1) / 16000;
    timeN = (0:length(signals{length(signals)})-1) / 16000;
    
    subplot(1,2,1);
    plot(time1, signals{1});
    title('Lowest Frequency Band Signal');
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;
    subplot(1,2,2);
    plot(timeN, signals{length(signals)});
    title('Highest Frequency Band Signal');
    xlabel('Time (s)');
    ylabel('Amplitude');
    grid on;
end

function split_signals = split_frequency(n, signal)
    split_signals = cell (1,n);
    low_freq = 100; % Hz
    hi_freq = 8000; % Hz
    freq_step = (hi_freq - low_freq) / n;
    for i = 1:n
        band_low = low_freq + (i-1) * freq_step;
        band_high = low_freq + i * freq_step; % Ensure we stay below Nyquist frequency
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