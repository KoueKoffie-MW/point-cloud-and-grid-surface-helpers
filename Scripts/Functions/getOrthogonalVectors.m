function [orthogonal1, orthogonal2] = getOrthogonalVectors(direction)
%GETORTHOGONALVECTORS Returns two unit vectors orthogonal (perpendicular) to a given 3D direction vector.
%
% This helper is used by cylindrical and spline-based point cloud generators
% (e.g. generateSplineCylinder, generateSplineCylinderPointCloud) to create
% a local coordinate frame around a spline direction for placing points on
% a cylinder surface.
%
% Inputs:
%   direction - 1x3 or 3x1 vector indicating the local tangent/direction
%
% Outputs:
%   orthogonal1 - First unit vector perpendicular to direction
%   orthogonal2 - Second unit vector perpendicular to both direction and orthogonal1
%
% See also:
%   generateSplineCylinder, generateSplineCylinderPointCloud, cross, norm
%
% Notes:
%   - Handles near-zero direction vectors gracefully by falling back to [1 0 0]
%   - Pure geometric helper with no side effects
%   - Designed for Simscape Multibody terrain/contact surface generation

    norm_dir = norm(direction);
    if norm_dir > eps
        direction = direction / norm_dir;
    else
        direction = [1, 0, 0];
    end

    [~, min_idx] = min(abs(direction));
    temp_vec = zeros(1, 3);
    temp_vec(min_idx) = 1;

    orthogonal1 = cross(direction, temp_vec);
    norm_orth1 = norm(orthogonal1);

    if norm_orth1 > eps
        orthogonal1 = orthogonal1 / norm_orth1;
    else
        temp_vec = zeros(1, 3);
        temp_vec(mod(min_idx, 3) + 1) = 1;
        orthogonal1 = cross(direction, temp_vec);
        if norm(orthogonal1) > eps
            orthogonal1 = orthogonal1 / norm(orthogonal1);
        else
            orthogonal1 = [1, 0, 0];
        end
    end

    orthogonal2 = cross(direction, orthogonal1);
end
