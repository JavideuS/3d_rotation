module StarRenderer

using LinearAlgebra

export render_rotating_star

# Quaternion operations
include("quaternion.jl")

# Constants for rotation
const α, β, δ = π / 8, π / 6, π / 8
const rotation_quat = euler_to_quat(α, β, δ)
export rotation_quat  # Export the constant

# Star geometry and rendering
include("star_geometry.jl")
include("renderer.jl")

# Main entry point function
function render_rotating_star()
    # Setup initial state
    print("\033[?25l")  # Hide cursor
    Base.exit_on_sigint(false)
    
    # Create initial star geometry
    recreate_star_vertices()
    
    # Main animation loop
    animation_loop()
    
    # Cleanup
    print("\033[?25h")  # Show cursor again
end

end # module