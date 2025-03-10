using LinearAlgebra

# Quaternion operations
function quat_mult(q1, q2)
    w1, x1, y1, z1 = q1
    w2, x2, y2, z2 = q2
    return [
        w1*w2 - x1*x2 - y1*y2 - z1*z2,
        w1*x2 + x1*w2 + y1*z2 - z1*y2,
        w1*y2 - x1*z2 + y1*w2 + z1*x2,
        w1*z2 + x1*y2 - y1*x2 + z1*w2
    ]
end

function quat_conj(q)
    return [q[1], -q[2], -q[3], -q[4]]
end

function quat_rotate(p, q)
    # Convert point to quaternion (w=0)
    p_quat = [0, p[1], p[2], p[3]]
    
    # Perform rotation: q * p * q_conj
    qp = quat_mult(q, p_quat)
    p_rot = quat_mult(qp, quat_conj(q))
    
    # Return rotated point (x, y, z)
    return p_rot[2:4]
end

# Euler angles to quaternion
function euler_to_quat(α, β, δ)
    # Half angles
    α2, β2, δ2 = α/2, β/2, δ/2
    
    # Calculate components
    cα, sα = cos(α2), sin(α2)
    cβ, sβ = cos(β2), sin(β2)
    cδ, sδ = cos(δ2), sin(δ2)
    
    # Combine rotations
    w = cα * cβ * cδ + sα * sβ * sδ
    x = sα * cβ * cδ - cα * sβ * sδ
    y = cα * sβ * cδ + sα * cβ * sδ
    z = cα * cβ * sδ - sα * sβ * cδ
    
    return [w, x, y, z]
end

# Add these quaternion-specific functions for rendering

# Convert barycentric coordinates to quaternion
function barycentric_to_quat(w1, w2, w3)
    # Use weights as a quaternion with w1 as real part
    return [w1, w2, w3, 0.0]
end

# Quaternion-based normal interpolation
function quat_interpolate_normal(n1, n2, n3, weights)
    # Convert normals to pure quaternions (w=0)
    q1 = [0.0, n1[1], n1[2], n1[3]]
    q2 = [0.0, n2[1], n2[2], n2[3]]
    q3 = [0.0, n3[1], n3[2], n3[3]]
    
    # Use SLERP-like quaternion interpolation
    w_quat = barycentric_to_quat(weights...)
    
    # Weighted sum using quaternion scaling
    result = [0.0, 0.0, 0.0, 0.0]
    for (q, w) in zip([q1, q2, q3], [weights[1], weights[2], weights[3]])
        scaled_q = q .* w
        result = result .+ scaled_q
    end
    
    # Extract vector part and normalize
    return normalize(result[2:4])
end

# Quaternion-based lighting calculation
function quat_calculate_lighting(normal::Vector{Float64}, light_dir::Vector{Float64})
    # Convert vectors to quaternions
    n_quat = [0.0, normal...]
    l_quat = [0.0, light_dir...]
    
    # Calculate quaternion dot product (similar to vector dot)
    dot_prod = quat_mult(n_quat, l_quat)
    
    # Extract the scalar part which gives us the dot product
    return dot_prod[1]
end

# Angles
const α, β, δ = π/8, π/6, π/8
const rotation_quat = euler_to_quat(α, β, δ)

# Characters classified by luminance
const luminance = ".,-~:;=!*#\$@"

const yellow_palette = [
    "\x1b[38;5;94m",   # Dark yellow
    "\x1b[38;5;100m",  # Darker golden
    "\x1b[38;5;136m",  # Gold
    "\x1b[38;5;142m",  # Goldenrod
    "\x1b[38;5;178m",  # Light goldenrod
    "\x1b[38;5;184m",  # Yellowish
    "\x1b[38;5;220m",  # Yellow-orange
    "\x1b[38;5;226m",  # Bright yellow
    "\x1b[38;5;227m",  # Pale yellow
    "\x1b[38;5;228m",  # Lighter yellow
    "\x1b[38;5;229m",  # Almost white-yellow
    "\x1b[38;5;15m"    # White (brightest)
]

# Terminal size -> (height, width)
terminal_size = displaysize(stdout)
# Center
center = round.(Int16, [terminal_size[2]/2, terminal_size[1]/2])
# Big radius
R = center[2]  

# Star outer points (edges)
outer_points = fill([0.0, 0.0, 0.0], 5)

θ = 72 # 360/5

for i in 0:4
   current_θ = 90 + (i * θ)
   outer_points[i + 1] = [R * cosd(current_θ), R * sind(current_θ), 0.0]
end

# Small radius 
r = R/2
# Inner points
inner_points = [[0.0, 0.0, 0.0] for _ in 1:5] 

for i in 0:4
   current_θ = 54 + (i * θ)
   inner_points[i+1] = [r * cosd(current_θ), r * sind(current_θ), 0.0]
end

# Define the range of the star in the terminal_matrix
x_range = round(Int16, (center[1] + outer_points[2][1])):round(Int16, (center[1] + outer_points[5][1]))

frame = fill(' ', terminal_size)
z_buffer = fill(Inf, terminal_size[1], terminal_size[2])

# Setting the depth of the star
star_depth = 5  # Increase layers for more smoothness

# Distance from screen
distance = R * 2.5  # Increased for better perspective effect

# Create a tapered star structure - larger at front, smaller at back
vertex_grid = [[] for _ in 1:star_depth]

# Scale factors for each layer (largest to smallest)
scale_factors = [1.0, 0.85, 0.7, 0.55, 0.4]

# Create layers with progressively smaller stars
for layer in 1:star_depth
    # Scale the points for this layer
    scale = scale_factors[layer]
    
    # Create scaled outer points
    layer_outer_points = similar(outer_points)
    for i in 1:5
        layer_outer_points[i] = [
            outer_points[i][1] * scale,
            outer_points[i][2] * scale,
            (layer-1) * .8  # Increase z-spacing between layers
        ]
    end
    
    # Create scaled inner points
    layer_inner_points = similar(inner_points)
    for i in 1:5
        layer_inner_points[i] = [
            inner_points[i][1] * scale,
            inner_points[i][2] * scale,
            (layer-1) * .8  # Same z as outer points in same layer
        ]
    end
    
    # Store this layer's points
    vertex_grid[layer] = [layer_outer_points..., layer_inner_points...]
end

star_triangles = [[[[0.0, 0.0, 0.0] for _ in 1:3] for _ in 1:8] for _ in 1:star_depth]

k1 = center[2] * distance * 3 / 2.5(R + r)

# Define triangles from points
function get_triangles(ext_points, int_points)
   # 8 triangles total
   triangles = [[[0.0, 0.0, 0.0] for _ in 1:3] for _ in 1:8]

   # Five outer triangles
   for i in 1:5
      triangles[i][1] = ext_points[i]
      for j in 0:1
          triangles[i][2+j] = int_points[((i + j - 1) % 5) + 1]
      end
   end

   # Three inner triangles
   for i in 1:3
      triangles[i+5][1] = [int_points[2i-1]...]
      triangles[i+5][2] = [int_points[2i%5]...]
      triangles[i+5][3] = [int_points[(i - 1) % 2 == 0 ? 3 : 5]...] 
   end
   return triangles
end

function calculate_luminance(normal::Vector{Float64}, depth::Float64)
    light_direction = normalize([0, -1/√2, -1/√2])  # Light direction
    
    # Base luminance from normal
    luminance_value = dot(normal, light_direction)
    
    # Add depth-based attenuation
    depth_factor = 1.0 - clamp(depth / 5.0, 0.0, 0.8)
    luminance_value = luminance_value * depth_factor
    
    # Normalize luminance value to range [0, 1]
    luminance_value = (luminance_value + 1) / 2

    # Convert to character index
    char_index = round(Int, luminance_value * (length(luminance) - 1))

    return char_index
end

function apply_color_and_char(lum_index::Int)
    color = yellow_palette[clamp(lum_index, 1, length(yellow_palette))]
    char = luminance[clamp(lum_index, 1, length(luminance))]
    
    return "$(color)$(char)\033[0m"  # Reset color with \033[0m
end

# Project a 3D point onto 2D screen using perspective projection
function project_point(point::Vector{Float64}, distance::Float64, center::Vector{Int16}, k1::Float64)
   ooz = 1 / (distance + point[3] )  # Z-depth projection
   x_proj = round(Int16, center[1] + k1 * point[1] * ooz)
   y_proj = round(Int16, center[2] - k1 * point[2] * ooz)
   return [x_proj, y_proj, ooz]
end

# Modified rasterizeTriangle function using quaternions
function rasterizeTriangle(p::Vector{Int16})
    for i in 1:star_depth
        for j in 1:8
            # Get the 3D vertices of the triangle
            A_3D = star_triangles[i][j][1]
            B_3D = star_triangles[i][j][2]
            C_3D = star_triangles[i][j][3]

            # Project the points to 2D (screen space)
            A_proj = project_point(A_3D, distance, center, k1)
            B_proj = project_point(B_3D, distance, center, k1)
            C_proj = project_point(C_3D, distance, center, k1)

            # Screen space point being rasterized
            alt_points = [p[2], p[1]]

            # Calculate barycentric weights using 2D projected points
            denom = (B_proj[2] - C_proj[2]) * (A_proj[1] - C_proj[1]) + (C_proj[1] - B_proj[1]) * (A_proj[2] - C_proj[2])
            if abs(denom) < 1e-10  # More robust check for zero
               continue
           end
            
            w1 = ((B_proj[2] - C_proj[2]) * (alt_points[1] - C_proj[1]) + (C_proj[1] - B_proj[1]) * (alt_points[2] - C_proj[2])) / denom
            w2 = ((C_proj[2] - A_proj[2]) * (alt_points[1] - C_proj[1]) + (A_proj[1] - C_proj[1]) * (alt_points[2] - C_proj[2])) / denom
            w3 = 1 - w1 - w2
            
            if w1 >= 0 && w2 >= 0 && w3 >= 0  # Point inside the triangle
                # Interpolate depth using quaternion weights
                weights = [w1, w2, w3]
                z = w1 * A_3D[3] + w2 * B_3D[3] + w3 * C_3D[3]

                # Z-buffer test with slight bias for depth sorting
                if z < z_buffer[p...] - 0.01
                    z_buffer[p...] = z

                    # Create view-dependent normals for better lighting
                    n1 = normalize([A_3D[1], A_3D[2], A_3D[3] * 1.2])
                    n2 = normalize([B_3D[1], B_3D[2], B_3D[3] * 1.2])
                    n3 = normalize([C_3D[1], C_3D[2], C_3D[3] * 1.2])
                    
                    # Use quaternion interpolation for normal
                    normal = quat_interpolate_normal(n1, n2, n3, [w1, w2, w3])
                    
                    # Calculate lighting with enhanced depth information
                    lum_index = calculate_luminance(normal, z)
                    
                    frame[p...] = apply_color_and_char(lum_index)
                end
            end
        end
    end
end

function update_frame()
   for (z, vertex) in enumerate(vertex_grid)
      star_triangles[z] = get_triangles(vertex[1:5], vertex[6:10])
   end
end

function print_frame(frame::Array, rows::Int, cols::Int)
   for i in 1:rows
      for j in 1:cols
         print(frame[i, j])
         if j == cols
            print("\n")
         end
      end
   end
   return nothing
end

# Main loop
while true
   print("\x1b[H") # Print at top left
   global frame = fill(" ", terminal_size)
   global z_buffer = fill(Inf, terminal_size)
   update_frame()
   
   for i in 1:terminal_size[1]
      for j in x_range
        rasterizeTriangle(round.(Int16, [i, j]))
      end
   end
   
   print_frame(frame, terminal_size[1], terminal_size[2])
   
   # Rotate points using quaternions
   for (i, depth) in enumerate(vertex_grid)
      for (j, point) in enumerate(depth)
         vertex_grid[i][j] = quat_rotate(point, rotation_quat)
      end
   end
   
   sleep(0.5)
   println("\033[2J\033[H")  # Clear screen
end