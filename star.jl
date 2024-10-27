#Libraries
using LinearAlgebra

#Angles
const α,β,δ = π/5, π/6, π/8
#Characters classified by luminance
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

#Terminal size -> (heigth,width)
terminal_size = displaysize(stdout)
#Center
center = round.(Int16,[terminal_size[2]/2 ,terminal_size[1]/2 ])


R=1
#It takes the smaller axis
if center[1] > center[2]
   #Big radius
   R = center[2]  
else
   R = center[1]
end

#Star outer points (edges)
#Setting them to 0.0 since I will use all the terminal for calculations and just round it when printing the point
#You treat the objecy as the center of the plane (not the screen)
outer_points = fill([0.0,0.0,0.0],5)

θ = 72 #360/5

#Starting at 90 degrees so the first point is in the positive y axis
for i in 0:4
   current_θ = 90 + (i * θ)
   outer_points[i + 1] = [R* cosd(current_θ), R * sind(current_θ),0]
end

#Small radius 
r = R/2
#Every outer points is supposed to have two more inner points, however, every triangles shares the inner point with other triangle
#So technically we only need to use 5 inner points 

inner_points = [[0.0, 0.0,0.0] for _ in 1:5] 

for i in 0:4
   current_θ = 58 + (i * θ)
   inner_points[i+1] = [r * cosd(current_θ), r * sind(current_θ),0]
end

#Then I define the range of my star in the terminal_matrix
#This will just help reduce the points to rasterize/fill
x_range = round(Int16,(center[1] + outer_points[2][1])):round(Int16,(center[1] + outer_points[5][1]))
#The star will use all the height so the y_range doesnt matter

frame = fill(" ", terminal_size)
z_buffer = fill(Inf, terminal_size[1], terminal_size[2])

#Setting the depth of the star
star_depth = 3
#To set how far away you want the star from the screen
distance = R * 1.5

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

k1= center[2]*distance*3/2.5((R+r))

#Now that we have the inner and outer points, now we can define the points for each triangle
#Each triangle will safe its each 3 points
function get_triangles(ext_points,int_points)

   #There are in total 8 triangles
   triangles = [[[0.0,0.0,0.0] for _ in 1:3] for _ in 1:8]

   #Five are what I call outer triangles
   for i in 1:5
      triangles[i][1] = ext_points[i]
      for j in 0:1
          triangles[i][2+j] = int_points[((i + j - 1) % 5) + 1]
      end
  end

  #The last three is what I considered as inner triangles
   for i in 1:3
      triangles[i+5][1] = [int_points[2i-1]...]
      triangles[i+5][2] = [int_points[2i%5]...]
      triangles[i+5][3] = [int_points[(i - 1) % 2 == 0 ? 3 : 5]...] 
   end
   return triangles
end

function calculate_luminance(normal::Vector{Float64})
   light_direction = normalize([0.0, -1.0, -1.0])  # Light direction (From below)
   
   luminance_value = dot(normal, light_direction)  # Dot product of normal and light direction

   # Normalize luminance value to range [0, 1]
   luminance_value = (luminance_value + 1) / 2

   # Convert luminance value to character index
   #We have a value between 0 and 1, so we multiply it by the number of characters and the round it to the nearest int
   #That way we get the index
   char_index = round(Int, luminance_value * (length(luminance) - 1))

   return char_index
end

# Function to project a 3D point onto 2D screen using perspective projection
function project_point(point::Vector{Float64}, distance::Float64, center::Vector{Int16}, k1::Float64)
   ooz = 1 / (distance + point[3])  # Z-depth projection (inverse of distance)
   x_proj = round(Int16, center[1] + k1 * point[1] * ooz)  # X projection
   y_proj = round(Int16, center[2] - k1 * point[2] * ooz)  # Y projection
   return [x_proj, y_proj, ooz]  # Return ooz (Z-buffer comparison value)
end

function apply_color_and_char(lum_index::Int)

   # Get color and character for the current lum_index
   #sometimes it can get to 0 and cause index error
   #clamp function is to avoid that
   color = yellow_palette[clamp(lum_index, 1, length(yellow_palette))]
   char = luminance[clamp(lum_index, 1, length(luminance))]
   
   # Return the combined color code and character as a string
   return "$(color)$(char)\033[0m"  # Reset color with \033[0m
end

function rasterizeTriangle(p::Vector{Int16})
   for i in 1:star_depth
      for j in 1:8
         # Get the 3D vertices of the triangle
         A_3D = star_triangles[i][j][1]  # 3D vertex A
         B_3D = star_triangles[i][j][2]  # 3D vertex B
         C_3D = star_triangles[i][j][3]  # 3D vertex C

         # Project the points to 2D (screen space)
         A_proj = project_point(A_3D, distance, center, k1)
         B_proj = project_point(B_3D, distance, center, k1)
         C_proj = project_point(C_3D, distance, center, k1)

         # Screen space point being rasterized (alt_points)
         alt_points = [p[2], p[1]]  # Using p... for dynamic matrix access

         # Calculate barycentric weights using 2D projected points
         denom = (B_proj[2] - C_proj[2]) * (A_proj[1] - C_proj[1]) + (C_proj[1] - B_proj[1]) * (A_proj[2] - C_proj[2])
         w1 = ((B_proj[2] - C_proj[2]) * (alt_points[1] - C_proj[1]) + (C_proj[1] - B_proj[1]) * (alt_points[2] - C_proj[2])) / denom
         w2 = ((C_proj[2] - A_proj[2]) * (alt_points[1] - C_proj[1]) + (A_proj[1] - C_proj[1]) * (alt_points[2] - C_proj[2])) / denom
         #Since all weights should add up to 1, we just need to calculate to of them
         w3 = 1 - w1 - w2
         #If every weight is positive, then the point is int he right side of the triangle
         if w1 >= 0 && w2 >= 0 && w3 >= 0  # Point inside the triangle
            # Interpolate depth in 3D space using barycentric coordinates
            z = w1 * A_3D[3] + w2 * B_3D[3] + w3 * C_3D[3]

            # Z-buffer test (use the real 3D z value for depth)
            if z < z_buffer[p...]  # Using p... for matrix access
               z_buffer[p...] = z

               # Interpolate the normal in 3D space
               normal = w1 * normalize(A_3D) + w2 * normalize(B_3D) + w3 * normalize(C_3D)

               # Calculate luminance based on interpolated 3D normal
               lum_index = calculate_luminance(normal)
               frame[p...] = apply_color_and_char(lum_index)  # Update frame with the correct luminance
            end
         end
      end
   end
end

function update_frame()
   for (z,vertex) in enumerate(vertex_grid)
      star_triangles[z] = get_triangles(vertex[1:5],vertex[6:10])
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

const x_rotation = [1     0       0   ;
              0   cos(α)  sin(α);
              0   -sin(α) cos(α)]

const y_rotation = [cos(β) 0 sin(β);
                0    1   0   ;
             -sin(β) 0 cos(β)]

const z_rotation = [cos(δ) sin(δ) 0;
             -sin(δ) cos(δ) 0;
                0      0    1]

while(true)
   print("\x1b[H") #Prints at the top left line
   global frame = fill(" ", terminal_size)
   global z_buffer = fill(Inf, terminal_size)
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
         vertex_grid[i][j] = z_rotation * y_rotation * x_rotation * points           
      end
   end
   sleep(0.5)
   println("\033[2J\033[H")  # ANSI escape code to clear the screen
end