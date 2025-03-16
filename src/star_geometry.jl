# Store star state in a mutable struct
mutable struct StarState
    # Terminal info
    terminal_size::Tuple{Int,Int}
    center::Vector{Int16}
    
    # Star geometry
    R::Float64  # Outer radius
    r::Float64  # Inner radius
    θ::Int      # Angular increment
    star_depth::Int
    
    # Rendering constants
    distance::Float64
    k1::Float64
    
    # Vertex data
    outer_points::Vector{Vector{Float64}}
    inner_points::Vector{Vector{Float64}}
    vertex_grid::Vector{Vector{Vector{Float64}}}
    star_triangles::Vector{Vector{Vector{Vector{Float64}}}}
    
    # Scale factors
    scale_factors::Vector{Float64}
    
    # Display buffers
    frame::Matrix{String}
    z_buffer::Matrix{Float64}
    
    # Constructor with sensible defaults
    function StarState()
        terminal_size = displaysize(stdout)
        center = round.(Int16, [terminal_size[2]/2, terminal_size[1]/2])
        R = center[2]
        r = R / 2
        θ = 72
        star_depth = 3
        distance = R * 2.5
        k1 = center[2] * distance * 3 / (2.5 * (R + r))
        
        outer_points = fill([0.0, 0.0, 0.0], 5)
        inner_points = fill([0.0, 0.0, 0.0], 5)
        vertex_grid = [[] for _ in 1:star_depth]
        star_triangles = [[[[0.0, 0.0, 0.0] for _ in 1:3] for _ in 1:8] 
                         for _ in 1:star_depth]
        
        scale_factors = star_depth == 3 ? [1/2, 1, 1/2] : [1/3, 2/3, 1, 2/3, 1/3]
        
        frame = fill(" ", terminal_size)
        z_buffer = fill(Inf, terminal_size)
        
        new(terminal_size, center, R, r, θ, star_depth, distance, k1,
            outer_points, inner_points, vertex_grid, star_triangles, 
            scale_factors, frame, z_buffer)
    end
end

# Global state - could be passed around as argument if preferred
const state = StarState()

# Constants for rendering
const luminance = ",~+*#@"
const yellow_palette = [
    "\x1b[38;5;94m",   # Dark olive/gold
    "\x1b[38;5;136m",  # Medium dark goldenrod
    "\x1b[38;5;178m",  # Dark gold
    "\x1b[38;5;220m",  # Gold
    "\x1b[38;5;221m",  # Light gold 
    "\x1b[38;5;226m",  # Bright yellow
]

# Create star geometry
function recreate_star_vertices()
    # Recreate outer points with new radius based on current terminal size
    for i in 0:4
        current_θ = 90 + (i * state.θ)
        state.outer_points[i + 1] = [state.R * cosd(current_θ), state.R * sind(current_θ), 0.0]
    end
    
    # Recreate inner points with new radius
    for i in 0:4
        current_θ = 54 + (i * state.θ)
        state.inner_points[i+1] = [state.r * cosd(current_θ), state.r * sind(current_θ), 0.0]
    end
    
    # Rebuild the vertex grid with new dimensions
    state.vertex_grid = [[] for _ in 1:state.star_depth]
    
    # Recreate layers with progressively smaller stars
    for layer in 1:state.star_depth
        scale = state.scale_factors[layer]
        
        # Create scaled outer points
        layer_outer_points = similar(state.outer_points)
        for i in 1:5
            layer_outer_points[i] = [
                state.outer_points[i][1] * scale,
                state.outer_points[i][2] * scale,
                (layer-1) * 0.6 # Increase z-spacing between layers
            ]
        end
        
        # Create scaled inner points
        layer_inner_points = similar(state.inner_points)
        for i in 1:5
            layer_inner_points[i] = [
                state.inner_points[i][1] * scale,
                state.inner_points[i][2] * scale,
                (layer-1) * 0.6 # Same z as outer points in same layer
            ]
        end
        
        # Store this layer's points
        state.vertex_grid[layer] = [layer_outer_points..., layer_inner_points...]
    end
end

# Define triangles from points
function get_triangles(ext_points, int_points)
    # 8 triangles total
    triangles = [[[0.0, 0.0, 0.0] for _ in 1:3] for _ in 1:8]

    # Five outer triangles
    for i in 1:5
        triangles[i][1] = ext_points[i]
        for j in 0:1
            triangles[i][2 + j] = int_points[((i + j - 1) % 5) + 1]
        end
    end

    # Three inner triangles
    for i in 1:3
        triangles[i + 5][1] = int_points[2 * i - 1]
        triangles[i + 5][2] = int_points[2 * i % 5 == 0 ? 5 : 2 * i % 5]
        triangles[i + 5][3] = int_points[(2 * (i + 1) - 1) % 5 == 0 ? 5 : (2 * (i + 1) - 1) % 5]
    end
    
    return triangles
end

# Initialize the star vertices when loaded
function __init__()
    recreate_star_vertices()
end
