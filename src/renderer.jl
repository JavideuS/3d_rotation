function animation_loop()
    last_size = state.terminal_size
    
    try
        while true
            # Check terminal size and update if changed
            last_size = handle_terminal_resize!(last_size)
            
            # Clear and prepare frame
            print("\x1b[H") 
            reset_frame_buffers!()
            update_frame()
            
            # Render current frame
            render_frame()
            
            # Rotate for next frame
            rotate_star_vertices!(rotation_quat)
            
            sleep(0.3)
        end
    catch e
        if isa(e, InterruptException)
            println("\nStopping animation")
        else
            println("\nError in animation loop: $(typeof(e))")
            rethrow(e)
        end
    finally
        # Make sure cursor is visible if anything goes wrong
        print("\033[?25h")
    end
end

function handle_terminal_resize!(last_size)
    current_size = displaysize(stdout)
    if current_size != last_size
        # Terminal size changed, update related dimensions
        state.terminal_size = current_size
        state.center = round.(Int16, [current_size[2]/2, current_size[1]/2])
        state.R = state.center[2]
        state.r = state.R / 2
        
        # Recreate geometry with new dimensions
        recreate_star_vertices()
        
        # Update projection constant
        state.k1 = state.center[2] * state.distance * 3 / (2.5 * (state.R + state.r))
        
        # Update reference size
        last_size = current_size
    end
    return last_size
end

function reset_frame_buffers!()
    state.frame = fill(" ", state.terminal_size)
    state.z_buffer = fill(Inf, state.terminal_size)
end

function render_frame()
    # Compute dynamic bounding box
    x_range, y_range = compute_bounding_box()
    
    # Render only within bounding box for efficiency
    for i in y_range
        for j in x_range
            rasterizeTriangle(round.(Int16, [i, j]))
        end
    end
    
    print_frame(state.frame, state.terminal_size[1], state.terminal_size[2])
end

function rotate_star_vertices!(rotation_quat)
    for (i, depth) in enumerate(state.vertex_grid)
        for (j, point) in enumerate(depth)
            state.vertex_grid[i][j] = quat_rotate(point, rotation_quat)
        end
    end
end

function update_frame()
    for (z, vertex) in enumerate(state.vertex_grid)
        state.star_triangles[z] = get_triangles(vertex[1:5], vertex[6:10])
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

# Define the range of the star in the terminal_matrix
function compute_bounding_box()
    # Find the min and max x,y values across all vertices in all layers
    min_x, max_x = Inf, -Inf
    min_y, max_y = Inf, -Inf
    
    for layer in 1:state.star_depth
        for point in state.vertex_grid[layer]
            # Project point to screen space
            projected = project_point(point, state.distance, state.center, state.k1)
            
            min_x = min(min_x, projected[1])
            max_x = max(max_x, projected[1])
            min_y = min(min_y, projected[2])
            max_y = max(max_y, projected[2])
        end
    end
    
    # Add padding and ensure bounds are within screen
    padding = 5
    min_x = max(1, round(Int16, min_x) - padding)
    max_x = min(state.terminal_size[2], round(Int16, max_x) + padding)
    min_y = max(1, round(Int16, min_y) - padding)
    max_y = min(state.terminal_size[1], round(Int16, max_y) + padding)
    
    return min_x:max_x, min_y:max_y
end

# Project a 3D point onto 2D screen using perspective projection
function project_point(point::Vector{Float64}, distance::Float64, center::Vector{Int16}, k1::Float64)
    ooz = 1 / (distance + point[3])  # Z-depth projection
    x_proj = round(Int16, center[1] + k1 * point[1] * ooz)
    y_proj = round(Int16, center[2] - k1 * point[2] * ooz)
    return [x_proj, y_proj, ooz]
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

function rasterizeTriangle(p::Vector{Int16})
    for i in 1:state.star_depth
        for j in 1:8
            # Get the 3D vertices of the triangle
            A_3D = state.star_triangles[i][j][1]
            B_3D = state.star_triangles[i][j][2]
            C_3D = state.star_triangles[i][j][3]

            # Project the points to 2D (screen space)
            A_proj = project_point(A_3D, state.distance, state.center, state.k1)
            B_proj = project_point(B_3D, state.distance, state.center, state.k1)
            C_proj = project_point(C_3D, state.distance, state.center, state.k1)

            # Screen space point being rasterized
            alt_points = [p[2], p[1]]
            
            # Add specialized line detection for near-degenerate triangles
            # This handles the case when the triangle becomes very thin (nearly a line)
            
            # Check if we're close to any edge of the triangle
            edge_proximity = min(
                point_to_line_distance(alt_points, A_proj[1:2], B_proj[1:2]),
                point_to_line_distance(alt_points, B_proj[1:2], C_proj[1:2]),
                point_to_line_distance(alt_points, C_proj[1:2], A_proj[1:2])
            )
            
            # If we're very close to an edge, treat it as part of the triangle
            if edge_proximity < 0.5
                # Apply same shading as you would for interior points
                # Determine which edge we're closest to for weighting
                z = (A_3D[3] + B_3D[3] + C_3D[3]) / 3  # Average depth for simplicity
                
                if z < state.z_buffer[p...] - 0.01
                    state.z_buffer[p...] = z
                    
                    # Create view-dependent normals for better lighting
                    n1 = normalize([A_3D[1], A_3D[2], A_3D[3] * 1.2])
                    n2 = normalize([B_3D[1], B_3D[2], B_3D[3] * 1.2])
                    n3 = normalize([C_3D[1], C_3D[2], C_3D[3] * 1.2])
                    
                    # Equal weight interpolation when on edge
                    normal = normalize(n1 + n2 + n3)
                    
                    # Calculate lighting with enhanced depth information
                    lum_index = calculate_luminance(normal, z)
                    
                    state.frame[p...] = apply_color_and_char(lum_index)
                end
                continue
            end

            # Calculate barycentric weights for interior points
            denom = (B_proj[2] - C_proj[2]) * (A_proj[1] - C_proj[1]) + (C_proj[1] - B_proj[1]) * (A_proj[2] - C_proj[2])
            if abs(denom) < 1e-10  # More robust check for zero
                continue
            end
            
            w1 = ((B_proj[2] - C_proj[2]) * (alt_points[1] - C_proj[1]) + (C_proj[1] - B_proj[1]) * (alt_points[2] - C_proj[2])) / denom
            w2 = ((C_proj[2] - A_proj[2]) * (alt_points[1] - C_proj[1]) + (A_proj[1] - C_proj[1]) * (alt_points[2] - C_proj[2])) / denom
            w3 = 1 - w1 - w2
            
            # More lenient test to catch points very close to edges
            if w1 >= -0.01 && w2 >= -0.01 && w3 >= -0.01  # Allow slight negative values to catch edge cases
                # Clamp weights to valid range for interpolation
                w1 = max(0.0, w1)
                w2 = max(0.0, w2)
                w3 = max(0.0, w3)
                
                # Renormalize weights
                total = w1 + w2 + w3
                if total > 0
                    w1 /= total
                    w2 /= total
                    w3 /= total
                else
                    w1 = w2 = w3 = 1/3  # Equal weights if all were negative
                end
                
                # Original interpolation code continues from here...
                weights = [w1, w2, w3]
                z = w1 * A_3D[3] + w2 * B_3D[3] + w3 * C_3D[3]

                if z < state.z_buffer[p...] - 0.01
                    state.z_buffer[p...] = z
                    
                    n1 = normalize([A_3D[1], A_3D[2], A_3D[3] * 1.2])
                    n2 = normalize([B_3D[1], B_3D[2], B_3D[3] * 1.2])
                    n3 = normalize([C_3D[1], C_3D[2], C_3D[3] * 1.2])
                    
                    normal = quat_interpolate_normal(n1, n2, n3, [w1, w2, w3])
                    
                    lum_index = calculate_luminance(normal, z)
                    
                    state.frame[p...] = apply_color_and_char(lum_index)
                end
            end
        end
    end
end

#Helper function for edge detection
function point_to_line_distance(point, line_start, line_end)
    if line_start == line_end
        return sqrt(sum((point .- line_start).^2))
    end
    
    # Vector from line_start to line_end
    line_vec = line_end .- line_start
    # Vector from line_start to point
    point_vec = point .- line_start
    
    # Project point_vec onto line_vec
    line_len = sqrt(sum(line_vec.^2))
    line_unitvec = line_vec ./ line_len
    projection_length = dot(point_vec, line_unitvec)
    
    # Handle points outside the line segment
    if projection_length < 0
        return sqrt(sum(point_vec.^2))
    elseif projection_length > line_len
        return sqrt(sum((point .- line_end).^2))
    end
    
    # Calculate perpendicular distance
    projection = line_start .+ line_unitvec .* projection_length
    distance = sqrt(sum((point .- projection).^2))
    
    return distance
end