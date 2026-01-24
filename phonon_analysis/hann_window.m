function w = hann_window(N)
%% HANN_WINDOW Create Hann (Hanning) window without Signal Processing Toolbox
%
% The Hann window is defined as:
%   w(n) = 0.5 * (1 - cos(2*pi*n/(N-1)))  for n = 0, 1, ..., N-1
%
% INPUT:
%   N - Window length
%
% OUTPUT:
%   w - Hann window [N x 1]
%
% This is equivalent to MATLAB's hanning() function from Signal Processing Toolbox.

n = (0:N-1)';
w = 0.5 * (1 - cos(2*pi*n/(N-1)));

end
