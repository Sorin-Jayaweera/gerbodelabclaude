function [D, eigenfreqs, eigenmodes] = compute_dynamical_matrix(x0, y0, neighbors, k_spring, lattice_constant)
%% COMPUTE_DYNAMICAL_MATRIX Compute dynamical matrix for harmonic approximation
%
% For a triangular lattice of particles interacting via harmonic springs,
% compute the dynamical matrix D where: m * d^2u/dt^2 = -D * u
%
% The eigenvalues of D give omega^2 (squared frequencies)
% The eigenvectors give the normal mode patterns
%
% INPUTS:
%   x0, y0          - Equilibrium positions [N_particles x 1]
%   neighbors       - Neighbor list [N_particles x max_neighbors] or cell array
%   k_spring        - Spring constant (can be scalar or matrix)
%   lattice_constant - Expected nearest-neighbor distance
%
% OUTPUTS:
%   D               - Dynamical matrix [2*N x 2*N] for 2D
%   eigenfreqs      - Eigenfrequencies (omega, not omega^2)
%   eigenmodes      - Eigenvectors reshaped to [N_particles, 2, N_modes]
%
% Author: Gerbode Lab

N = length(x0);

% If neighbors is not provided, compute from positions
if nargin < 3 || isempty(neighbors)
    fprintf('Computing neighbor list from positions...\n');
    neighbors = find_neighbors_from_positions(x0, y0, lattice_constant * 1.2);
end

% Default spring constant
if nargin < 4 || isempty(k_spring)
    k_spring = 1.0;
end

if nargin < 5 || isempty(lattice_constant)
    lattice_constant = estimate_lattice_constant(x0, y0);
end

%% Build dynamical matrix
% For 2D, the dynamical matrix is 2N x 2N
% Indexing: particle i has x at index 2*i-1, y at index 2*i

D = zeros(2*N, 2*N);

% Convert neighbors to cell array if needed
if ~iscell(neighbors)
    neighbors_cell = cell(N, 1);
    for i = 1:N
        row = neighbors(i, :);
        neighbors_cell{i} = row(row > 0 & row <= N);
    end
    neighbors = neighbors_cell;
end

for i = 1:N
    xi = x0(i);
    yi = y0(i);

    % Indices in dynamical matrix
    ix = 2*i - 1;
    iy = 2*i;

    nn = neighbors{i};

    for jj = 1:length(nn)
        j = nn(jj);
        if j == 0 || j > N
            continue;
        end

        xj = x0(j);
        yj = y0(j);

        % Vector from i to j
        dx = xj - xi;
        dy = yj - yi;
        r = sqrt(dx^2 + dy^2);

        if r < 1e-10
            continue;
        end

        % Unit vector
        nx = dx / r;
        ny = dy / r;

        % Indices for particle j
        jx = 2*j - 1;
        jy = 2*j;

        % Off-diagonal blocks (coupling between i and j)
        % D_ij = -k * n_ij (x) n_ij (outer product)
        D(ix, jx) = D(ix, jx) - k_spring * nx * nx;
        D(ix, jy) = D(ix, jy) - k_spring * nx * ny;
        D(iy, jx) = D(iy, jx) - k_spring * ny * nx;
        D(iy, jy) = D(iy, jy) - k_spring * ny * ny;

        % Diagonal blocks (self-interaction, sum of all bonds)
        D(ix, ix) = D(ix, ix) + k_spring * nx * nx;
        D(ix, iy) = D(ix, iy) + k_spring * nx * ny;
        D(iy, ix) = D(iy, ix) + k_spring * ny * nx;
        D(iy, iy) = D(iy, iy) + k_spring * ny * ny;
    end
end

%% Solve eigenvalue problem
fprintf('Computing eigenvalues and eigenvectors...\n');

% Make sure D is symmetric
D = (D + D') / 2;

[V, Lambda] = eig(D);
lambda = diag(Lambda);

% Sort by eigenvalue
[lambda_sorted, sort_idx] = sort(lambda);
V_sorted = V(:, sort_idx);

% Eigenfrequencies (omega = sqrt(lambda), but handle negative eigenvalues)
% First 2-3 should be ~0 (rigid body translations/rotation)
eigenfreqs = sqrt(max(lambda_sorted, 0));

% Reshape eigenvectors to [N_particles, 2, N_modes]
eigenmodes = zeros(N, 2, 2*N);
for m = 1:2*N
    mode = V_sorted(:, m);
    eigenmodes(:, 1, m) = mode(1:2:end);  % x components
    eigenmodes(:, 2, m) = mode(2:2:end);  % y components
end

fprintf('Found %d modes\n', length(eigenfreqs));
fprintf('First 6 eigenfrequencies (expect ~0 for translations): \n');
disp(eigenfreqs(1:min(6, length(eigenfreqs)))');

end

function neighbors = find_neighbors_from_positions(x0, y0, cutoff)
    % Find neighbors within cutoff distance
    N = length(x0);
    neighbors = cell(N, 1);

    for i = 1:N
        dx = x0 - x0(i);
        dy = y0 - y0(i);
        r = sqrt(dx.^2 + dy.^2);
        neighbors{i} = find(r > 0 & r < cutoff)';
    end
end

function a = estimate_lattice_constant(x0, y0)
    % Estimate lattice constant from nearest neighbor distances
    N = length(x0);
    min_dists = zeros(N, 1);

    for i = 1:N
        dx = x0 - x0(i);
        dy = y0 - y0(i);
        r = sqrt(dx.^2 + dy.^2);
        r(i) = inf;
        min_dists(i) = min(r);
    end

    a = mean(min_dists);
    fprintf('Estimated lattice constant: %.3f\n', a);
end
