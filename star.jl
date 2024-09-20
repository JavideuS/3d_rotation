#Libraries
using LinearAlgebra

#Angles
α,β,δ = π/8, π/8, π/8
#Characters classified by luminance
luminance = "@\$#*!=;:~-,."


#Terminal size -> (heigth,width)
terminal_size = displaysize(stdout)
#Center
center = round.(Int16,[terminal_size[1]/2 ,terminal_size[2]/2 ])
#Big radius
R = center[1]  

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

#Now that we have the inner and outer points, now we can define the points for each triangle
#Each triangle will safe its each 3 points
outer_triangles = [[[0.0, 0.0] for _ in 1:3] for _ in 1:5]
for i in 1:5
   outer_triangles[i][1][2] = outer_points[i][2]
   outer_triangles[i][1][1] = outer_points[i][1]
   for j in 0:1
      outer_triangles[i][2+j][1] = inner_points[((i+ j - 1) % 5) + 1][1] 
      outer_triangles[i][2+j][2] = inner_points[((i+j - 1) % 5) + 1][2]
   end
end

#Now we define the inner triangles which are combinations 
inner_triangles = [[[0.0, 0.0] for _ in 1:3] for _ in 1:3]
for i in 1:3
   inner_triangles[i][1] = [inner_points[2i-1]...]
   inner_triangles[i][2] = [inner_points[2i%5]...]
   inner_triangles[i][3] = [inner_points[(i - 1) % 2 == 0 ? 3 : 5]...] 
end

star_triangles = [outer_triangles...,inner_triangles...]

function cross2d(v1, v2)
   if size(v1) != size(v2) != 2
      throw(ArgumentError("Vector must have exactly 2 elements"))
   end
   return v1[1] * v2[2] - v1[2] * v2[1]
end

function rasterizeTriangle(point::Vector{Int16})
   for i in 1:8
      # AP x AB
      first_edge = cross2d((point - (center .- star_triangles[i][1])),((center - star_triangles[i][2]) - (center .- star_triangles[i][1]))) 
      #BP x BC
      second_edge = cross2d((point - (center .- star_triangles[i][2])),((center - star_triangles[i][3]) - (center .- star_triangles[i][2])))  
      #CP x cA
      third_edge = cross2d((point - (center .- star_triangles[i][3])),((center - star_triangles[i][1]) - (center .- star_triangles[i][3]))) 

      if (first_edge >= 0  && second_edge >= 0 && third_edge >=0 ) || (first_edge <= 0  && second_edge <= 0 && third_edge <= 0)
         frame[point...] = '#'
         break
      end
   end
end

#Then I define the range of my star in the terminal_matrix
#This will just help reduce the points to rasterize/fill
x_range = round(Int16,(center[2] + outer_points[2][2])):round(Int16,(center[2] + outer_points[5][2]))
#The the star will use all the height so the y_range doesnt matter

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


k1= center[1]*distance*3/4((R+r))
function update_frame()
   for depth in vertex_grid
      for points in depth
         #It is formatted (y,x)
         ooz = 1/(distance + points[3])
         x′ = k1 * points[1] * ooz
         y′ = k1 * points[2] * ooz
         pos = round.(Int16,[center[1] - y′,center[2] + x′])
         if pos[1] < 1
            pos[1] = 1
         end
         ilumin_index = round(Int16,points[3]+1)
         if ilumin_index < 1
            ilumin_index = 1
         elseif  ilumin_index > 12
            ilumin_index = 12
         end
         frame[pos...] = luminance[ilumin_index]
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

                

# for i in 1:terminal_size[1]
#    for j in (center[2] + outer_points[2][2]):terminal_size[2]
#      rasterizeTriangle(Int16.([i, j]))
#    end
# end
while(true)
   print("\x1b[H") #Prints at the top left line
   frame = fill(' ', terminal_size)
   update_frame()
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