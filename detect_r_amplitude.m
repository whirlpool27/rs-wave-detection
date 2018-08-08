% close other window(s)
close;

% define cut off frequency, sampling frequency
fc = 0.5;
fs = 360;

% create notch filter
[num, den] = iirnotch(60/128*2, 60/128*2/35);
notch_filtered = filter(num, den, ecg10);

% create butterworth hpf from cut off frequency
[b, a] = butter(7, [2*fc/fs 2*150/fs], 'bandpass');
ecg_filtered = filter(b, a, notch_filtered);

% calculate moving average to get a smoother curve
ma = movmean(ecg_filtered, 3);

% see moving average trend (rising, falling, sideways)
trend = diff(ma);

% initialize state
state = 1:(length(ecg_filtered)-1);

% search for big rise/fall to get R wave
threshold = max(ecg_filtered)/20;
pos_flag = false;
pos_start = 0;
pos_rest = false;
neg_flag = false;
neg_start = 0;
neg_rest = false;

for i = 1:(length(ecg_filtered)-1)
    if trend(i) > threshold % rising
        if(not(neg_rest) && not(pos_rest))
            state(i) = 1;
            pos_flag = true;
        else
            state(i) = 0;
        end
    elseif trend(i) < -threshold % falling
        if (pos_flag == true && not(neg_rest))
            state(i) = -1;
            neg_flag = true;
            pos_rest = false;
        else
            state(i) = 0;
        end
    else % sideways
        state(i) = 0;
        if (neg_flag)
            neg_rest = true;
            neg_start = i;
            neg_flag = false;
        end
        if (pos_flag)
            pos_rest = true;
            pos_start = i;
        end
        
    end
    
    if(pos_rest)
        if i - pos_start > fs/12
            pos_rest = false;
            state(pos_start:i) = 0;
        end
    end
    if (neg_rest)
        if i - neg_start > fs/4
            neg_rest = false;
            pos_flag = false;
        end
    end
        
end

plot(ecg_filtered)
hold on;
% plot(state)


% initialize variables for R amplitude searching
activated = false;
secondstage = false;
start = 1;
finish = 1;
j = 1;

% get R amplitude
for i = 1:(length(ecg_filtered)- 1)
    if state(i) == 1 % rising, start point for R wave amplitude searching
        if (not(activated))
            activated = true;
            start = i;
        end
    elseif state(i) == -1 % falling
        if(activated)
            secondstage = true;
        end
    else % state back to 0 after falling, end point
        if(secondstage)             
            if i < length(ecg_filtered)-fs/6
                finish = i+fs/6;
            else
                finish = i;
            end
            R(j) = max(ecg_filtered(start:finish));
            S(j) = min(ecg_filtered(start:finish));
            loc(j) = start + find(ecg_filtered(start:finish) == R(j));
            j = j+1;
            
            activated = false;
            secondstage = false;          
            
        end
    end         
end

plot(loc, R, 'ro');
hold off;
% search for delta amplitude
deltaRS = zeros(length(R),1);

for i = 1:length(R)
    deltaRS(i) = R(i)+S(i);
end

figure;
[qrspeaks, locs] = findpeaks(ecg_filtered, 1:length(ecg_time), 'MinPeakHeight', 0.2, 'MinPeakDistance', fs/4);
plot(ecg_filtered);
hold on;
plot(locs, qrspeaks, 'ro');
hold off;
