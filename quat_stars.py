import numpy as np
import matplotlib.pyplot as plt

def quaternion_rotation(p, q):
    """Rotates point p by quaternion q using q * p * q_conjugate."""
    q_conj = np.array([q[0], -q[1], -q[2], -q[3]])  # Quaternion conjugate
    p_quat = np.array([0, p[0], p[1], 0])  # Represent 2D point as quaternion

    # Quaternion multiplication: q * p
    qp = quat_mult(q, p_quat)
    # Multiply result by q_conjugate
    p_rot = quat_mult(qp, q_conj)

    return p_rot[1], p_rot[2]  # Extract x, y

def quat_mult(q1, q2):
    """Multiplies two quaternions."""
    w1, x1, y1, z1 = q1
    w2, x2, y2, z2 = q2
    return np.array([
        w1*w2 - x1*x2 - y1*y2 - z1*z2,
        w1*x2 + x1*w2 + y1*z2 - z1*y2,
        w1*y2 - x1*z2 + y1*w2 + z1*x2,
        w1*z2 + x1*y2 - y1*x2 + z1*w2
    ])

def generate_star(n, s):
    """Generates star polygon with n points and step s using quaternion rotations."""
    angle = 2 * np.pi / n * s  # Star step rotation
    q = np.array([np.cos(angle / 2), 0, 0, np.sin(angle / 2)])  # Rotation quaternion

    points = []
    p = np.array([1, 0])  # Start at (1,0)

    for _ in range(n):
        points.append(p)
        p = quaternion_rotation(p, q)  # Rotate using quaternion multiplication

    return np.array(points)

def plot_star(n, s, title="Star Polygon"):
    """Plots a star polygon with given n (points) and s (step size)."""
    points = generate_star(n, s)

    plt.figure(figsize=(6, 6))
    plt.plot(*zip(*points, points[0]), marker="o", linestyle="-")
    plt.title(f"{title} ({n}, {s})")
    plt.xlim(-1.2, 1.2)
    plt.ylim(-1.2, 1.2)
    plt.gca().set_aspect("equal")
    plt.grid(True)
    plt.show()

# Example: Plot a pentagram (5,2) and a heptagram (7,3)
plot_star(5, 2, "Pentagram")
plot_star(7, 3, "Heptagram")
