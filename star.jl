#Libraries
using LinearAlgebra

#Angles
α,β,δ = π/8, π/8, π/8
#Characters classified by luminance
#luminance = "@\$#*!=;:~-,."
luminance = ".,-~:;=!*#\$@"

#Terminal size -> (heigth,width)
terminal_size = displaysize(stdout)
#Center
center = round.(Int16,[terminal_size[2]/2 ,terminal_size[1]/2 ])
#Big radius
R = center[2]  

#Star outer points (edges)
#Setting them to 0.0 since I will use all the terminal for calculations and just round it when printing the point
#You treat the objecy as the center of the plane (not the screen)
outer_points = fill([0.0,0.0,0.0],5)

θ = 72 #360/5

for i in 0:4
   current_θ = 90 + (i * θ)
   outer_points[i + 1] = [R* cosd(current_θ), R * sind(current_θ),0]
end

#Small radius
r = R/2
#Each edge will have to corresponding inner points (But since each triangle share a point) it will only save half
inner_points = [[0.0, 0.0,0.0] for _ in 1:5] 

for i in 0:4
   current_θ = 58 + (i * θ)
   inner_points[i+1] = [r * cosd(current_θ), r * sind(current_θ),0]
end

#Then I define the range of my star in the terminal_matrix
#This will just help reduce the points to rasterize/fill
x_range = round(Int16,(center[1] + outer_points[2][1])):round(Int16,(center[1] + outer_points[5][1]))
#The star will use all the height so the y_range doesnt matter

#RGB code colors
light_red, medium_light_red, medium_red, medium_dark_red, dark_red = 211, 204, 196, 160, 88  
#Shades from brightest to darkest
shades = [light_red, medium_light_red, medium_red, medium_dark_red, dark_red]

frame = fill(' ', terminal_size)
z_buffer = fill(Inf, terminal_size[1], terminal_size[2])

#Setting the depth of the star
star_depth = 3
#To set how far away you want the star from the screen
distance= R * 1.5

#Vector containing center, outer vertex and inner vertex
vertex_grid = [[outer_points...,inner_points...] for _ in 1:star_depth]

for i in 1:star_depth-1
   #Number of vertex
   for j in 1:10
      #i+1 to adjust julia 1_indexed
      vertex_grid[i+1][j] = vertex_grid[i+1][j] .+ [0,0,i]
   end
end

star_triangles = [[[[0,0,0.0] for _ in 1:3] for _ in 1:8] for _ in 1:star_depth]
norms = [[0 for _ in 1:8] for _ in 1:star_depth]

k1= center[2]*distance*3/4((R+r))

function update_frame()
   for (z,vertex) in enumerate(vertex_grid)
      star_triangles[z] = get_triangles(vertex[1:5],vertex[6:10])
      norms[z] = calculate_luminance(star_triangles[z])
   end
end

# Perspective Projection with depth influence
function project_point(point::Vector{Float64}, distance::Float64, center::Vector{Int16}, k1::Float64)
   ooz = 1 / (distance + point[3])  # Z-depth projection (inverse of distance)
   x_proj = round(Int16, center[1] + k1 * point[1] * ooz)  # X projection
   y_proj = round(Int16, center[2] - k1 * point[2] * ooz)  # Y projection
   #Comparing with ooz instead of normal Z
   #Since ooz is related to the screen
   return [x_proj, y_proj, point[3]]  # Projected X, Y and Z (for Z-buffer)
end


#Now that we have the inner and outer points, now we can define the points for each triangle
#Each triangle will safe its each 3 points
function get_triangles(ext_points,int_points)

   xd = [[[0.0,0.0,0.0] for _ in 1:3] for _ in 1:8]
   for i in 1:5
      xd[i][1] = ext_points[i]
      for j in 0:1
          xd[i][2+j] = int_points[((i + j - 1) % 5) + 1]
      end
  end

   for i in 1:3
      xd[i+5][1] = [int_points[2i-1]...]
      xd[i+5][2] = [int_points[2i%5]...]
      xd[i+5][3] = [int_points[(i - 1) % 2 == 0 ? 3 : 5]...] 
   end
   tri = copy(xd)
   return tri
end

function calculate_luminance(triangles)
   light_values = [0 for _ in 1:8]
   for i in 1:8
      A, B, C = triangles[i][1], triangles[i][2], triangles[i][3]

      # Step 1: Calculate edges
      edge1 = B .- A
      edge2 = C .- A

      # Step 2: Calculate the normal vector using the cross product
      normal = cross(edge1, edge2)

      # Step 3: Normalize the normal vector
      norm_length = sqrt(sum(normal .^ 2))
      normalized_normal = normal / norm_length

      # Step 4: Compute dot product with light direction (assumed from -Z axis)
      light_direction = [0, 0, -1]
      dot_product = dot(normalized_normal, light_direction)
      
      # Step 5: Incorporate Z-depth in luminance calculation
      average_z = (A[3] + B[3] + C[3]) / 3  # Average Z value of the triangle
      depth_factor = max(0, 1 - (average_z / distance))  # Depth effect (closer triangles are brighter)
      
      # Step 6: Combine dot product and depth factor to get final luminance
      luminance_value = ((dot_product + 1) / 2) * depth_factor  # Normalize to range [0, 1]

      # Convert luminance to character index and clamp between 1 and 12
      char_index = round(Int, luminance_value * (length(luminance) - 1))
      char_index = clamp(char_index + 1, 1, length(luminance))  # Ensure index is between 1 and 12
      light_values[i] = char_index  # Luminance index for triangle
   end
   return light_values
end




function cross2d(v1, v2)
   if size(v1) != size(v2) != 2
      throw(ArgumentError("Vector must have exactly 2 elements"))
   end
   return v1[1] * v2[2] - v1[2] * v2[1]
end

# Function to project a 3D point onto 2D screen using perspective projection
function project_point(point::Vector{Float64}, distance::Float64, center::Vector{Int16}, k1::Float64)
   ooz = 1 / (distance + point[3])  # Z-depth projection (inverse of distance)
   x_proj = round(Int16, center[1] + k1 * point[1] * ooz)  # X projection
   y_proj = round(Int16, center[2] - k1 * point[2] * ooz)  # Y projection
   return [x_proj, y_proj, ooz]  # Return ooz (Z-buffer comparison value)
end

function rasterizeTriangle(p::Vector{Int16})
   for i in 1:star_depth
      for j in 1:8
         A = project_point(star_triangles[i][j][1], distance, center, k1)
         B = project_point(star_triangles[i][j][2], distance, center, k1)
         C = project_point(star_triangles[i][j][3], distance, center, k1)

         alt_points = [p[2],p[1]]
         # Calculate barycentric weights
         denom = (B[2] - C[2]) * (A[1] - C[1]) + (C[1] - B[1]) * (A[2] - C[2])
         w1 = ((B[2] - C[2]) * (alt_points[1] - C[1]) + (C[1] - B[1]) * (alt_points[2] - C[2])) / denom
         w2 = ((C[2] - A[2]) * (alt_points[1] - C[1]) + (A[1] - C[1]) * (alt_points[2] - C[2])) / denom
         w3 = 1 - w1 - w2

         if w1 >= 0 && w2 >= 0 && w3 >= 0  # Inside the triangle
            z = w1 * A[3] + w2 * B[3] + w3 * C[3]  # Interpolate the ooz (1/Z) value
            if z < z_buffer[p...]  # Check Z-buffer
               z_buffer[p...] = z
               frame[p...] = luminance[norms[i][j]]  # Update frame with luminance
            end
         end
      end
   end
end

function print_frame(frame::Array,rows::Int, cols::Int)
   #number of cols -> width, number of rows -> height
   for i in 1:rows
      for j in 1:cols
         print(frame[i,j])
         if j == rows 
            print("\n")
         end
      end
   end   
   return nothing
end

x_rotation = [1     0       0   ;
              0   cos(α)  sin(α);
              0   -sin(α) cos(α)]

y_rotation = [cos(β) 0 sin(β);
                0    1   0   ;
             -sin(β) 0 cos(β)]

z_rotation = [cos(δ) sin(δ) 0;
             -sin(δ) cos(δ) 0;
                0      0    1]

while(true)
   print("\x1b[H") #Prints at the top left line
   frame = fill(' ', terminal_size)
   z_buffer = fill(Inf, terminal_size)
   update_frame()
   for i in 1:terminal_size[1]
      for j in x_range
        rasterizeTriangle(round.(Int16,[i, j]))
      end
   end
   print_frame(frame, terminal_size[1],terminal_size[2])
   for (i,depth) in enumerate(vertex_grid)
      for (j,points) in enumerate(depth)               
         #It is formatted (y,x)               
         vertex_grid[i][j] = x_rotation * y_rotation * points           
      end
   end
   sleep(0.5)
   println("\033[2J\033[H")  # ANSI escape code to clear the screen
end