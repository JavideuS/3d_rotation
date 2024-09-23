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

star_triangles = [[[[0,0] for _ in 1:3] for _ in 1:8] for _ in 1:star_depth]
norms = [[0 for _ in 1:8] for _ in 1:star_depth]

k1= center[2]*distance*3/4((R+r))
function update_frame()
   for (z,depth) in enumerate(vertex_grid)
      a = [Int16.([0,0]) for _ in 1:10]
      norms[z] = calculate_luminance(get_triangles(depth[1:5],depth[6:10],3))
      for (y,points) in enumerate(depth)
         #It is formatted (y,x)
         ooz = 1/(distance + points[3])
         x′ = k1 * points[1] * ooz
         y′ = k1 * points[2] * ooz
         pos = round.(Int16,[center[2] - y′,center[1] + x′])
         a[y] = [pos[2],pos[1]]
      end
      star_triangles[z] = get_triangles(a[1:5],a[6:10],2)
   end
end

#Now that we have the inner and outer points, now we can define the points for each triangle
#Each triangle will safe its each 3 points
function get_triangles(ext_points,int_points,dimension)
   if dimension == 2
      xd = [[[0,0] for _ in 1:3] for _ in 1:8]
   elseif dimension == 3
      xd = [[[0.0,0.0,0.0] for _ in 1:3] for _ in 1:8]
   else
      return -1
   end
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
   return xd
end

function calculate_luminance(triangles)

   light_value = [0 for _ in 1:8]
   for i in 1:8
      A = triangles[i][1]
      B = triangles[i][2]
      C = triangles[i][3]

      # Step 1: Calculate edges
      edge1 = (B[1] - A[1], B[2] - A[2], B[3] - A[3])  # B - A
      edge2 = (C[1] - A[1], C[2] - A[2], C[3] - A[3])  # C - A

      normal = (
        edge1[2] * edge2[3] - edge1[3] * edge2[2],  # i-component
        edge1[3] * edge2[1] - edge1[1] * edge2[3],  # j-component
        edge1[1] * edge2[2] - edge1[2] * edge2[1]   # k-component
    )

      norm_length = sqrt(normal[1]^2 + normal[2]^2 + normal[3]^2)
      normalized_normal = (normal[1] / norm_length, normal[2] / norm_length, normal[3] / norm_length)
      light_direction = normalize([0, 0, -1])  # Light coming from in front
      dot_product = dot(normalized_normal, light_direction)  # Dot product of normal and light direction
      luminance_value = (dot_product + 1) / 2  # Normalize from [-1, 1] to [0, 1]

      # Convert luminance_value to an index
      char_index = round(Int, luminance_value * (length(luminance) - 1))

      # Get the corresponding character
      light_value[i] = char_index + 1
   end
   return light_value
end


function cross2d(v1, v2)
   if size(v1) != size(v2) != 2
      throw(ArgumentError("Vector must have exactly 2 elements"))
   end
   return v1[1] * v2[2] - v1[2] * v2[1]
end

function rasterizeTriangle(point::Vector{Int16})
   for i in 1:star_depth
      for j in 1:8
         # AP x AB
         alt_points = [point[2],point[1]]
         first_edge = cross2d((alt_points -  star_triangles[i][j][1]),(star_triangles[i][j][2] - star_triangles[i][j][1])) 
         #BP x BC
         second_edge = cross2d((alt_points -  star_triangles[i][j][2]),(star_triangles[i][j][3] - star_triangles[i][j][2]))  
         #CP x cA
         third_edge = cross2d((alt_points - star_triangles[i][j][3]),(star_triangles[i][j][1] - star_triangles[i][j][3])) 

         if (first_edge >= 0  && second_edge >= 0 && third_edge >=0 ) || (first_edge <= 0  && second_edge <= 0 && third_edge <= 0)
            if frame[point...] == ' ' || norms[i][j] > findfirst(frame[point...],luminance)
               frame[point...] = luminance[norms[i][j]]
            end
            break
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