# Quaternion type for clarity
struct Quaternion
    w::Float64
    x::Float64
    y::Float64
    z::Float64
end

# Constructor from array
Quaternion(q::Vector{<:Real}) = Quaternion(q[1], q[2], q[3], q[4])

# Vector representation
to_vector(q::Quaternion) = [q.w, q.x, q.y, q.z]

function quat_mult(q1::Quaternion, q2::Quaternion)
    w1, x1, y1, z1 = q1.w, q1.x, q1.y, q1.z
    w2, x2, y2, z2 = q2.w, q2.x, q2.y, q2.z
    
    return Quaternion(
        w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2,
        w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
        w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
        w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2
    )
end

function quat_conj(q::Quaternion)
    return Quaternion(q.w, -q.x, -q.y, -q.z)
end

# For compatibility with existing code
quat_mult(q1::Vector, q2::Vector) = to_vector(quat_mult(Quaternion(q1), Quaternion(q2)))
quat_conj(q::Vector) = to_vector(quat_conj(Quaternion(q)))

function quat_rotate(p::Vector{<:Real}, q::Vector{<:Real})
    # Convert point to quaternion (w=0)
    p_quat = Quaternion(0, p[1], p[2], p[3])
    q_quat = Quaternion(q)
    
    # Perform rotation: q * p * q_conj
    qp = quat_mult(q_quat, p_quat)
    p_rot = quat_mult(qp, quat_conj(q_quat))
    
    # Return rotated point (x, y, z)
    return [p_rot.x, p_rot.y, p_rot.z]
end

# Euler angles to quaternion
function euler_to_quat(α, β, δ)
    # Half angles
    α2, β2, δ2 = α / 2, β / 2, δ / 2
    
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

# Enhance functions with structured quaternion types
function quat_interpolate_normal_enhanced(n1, n2, n3, weights)
    # Convert normals to pure quaternions (w=0)
    q1 = Quaternion(0.0, n1[1], n1[2], n1[3])
    q2 = Quaternion(0.0, n2[1], n2[2], n2[3])
    q3 = Quaternion(0.0, n3[1], n2[3], n3[3])
    
    # Weighted sum using quaternion scaling
    result = Quaternion(0.0, 0.0, 0.0, 0.0)
    qs = [q1, q2, q3]
    for i in 1:3
        # Scale quaternion by weight
        scaled_w = qs[i].w * weights[i]
        scaled_x = qs[i].x * weights[i]
        scaled_y = qs[i].y * weights[i]
        scaled_z = qs[i].z * weights[i]
        
        # Add to result
        result = Quaternion(
            result.w + scaled_w,
            result.x + scaled_x,
            result.y + scaled_y,
            result.z + scaled_z
        )
    end
    
    # Extract vector part and normalize
    vector_part = [result.x, result.y, result.z]
    return normalize(vector_part)
end