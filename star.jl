#Libraries
using LinearAlgebra

#Angles
α,β,δ = π/2, π/4, π/8
#Characters classified by luminance
luminance = ".,-~:;=!*#\$@"


#Terminal size -> (heigth,width)
terminal_size = displaysize(stdout)
#Center
center = round.(Int16,[terminal_size[1]/2 ,terminal_size[2]/2 ])
#Big radius
R = center[1] 

#Star outer points (edges)
outer_points = fill([0,0],5)

θ = 72 #360/5

for i in 0:4
   current_θ = 90 + (i * θ)
   outer_points[i + 1] = round.(Int16,[R* sind(current_θ), R * cosd(current_θ)])
end

#Small radius
r = R/2
#Each edge will have to corresponding inner points (But since each triangle share a point) it will only save half
inner_points = [[0, 0] for _ in 1:5] 

for i in 0:4
   current_θ = 58 + (i * θ)
   inner_points[i+1] = round.(Int16,[r * sind(current_θ), r * cosd(current_θ)])
end

#Now that we have the inner and outer points, now we can define the points for each triangle
#Each triangle will safe its each 3 points
outer_triangles = [[[0, 0] for _ in 1:3] for _ in 1:5]
for i in 1:5
   outer_triangles[i][1][1] = outer_points[i][1]
   outer_triangles[i][1][2] = outer_points[i][2]
   for j in 0:1
      outer_triangles[i][2+j][1] = inner_points[((i+ j - 1) % 5) + 1][1] 
      outer_triangles[i][2+j][2] = inner_points[((i+j - 1) % 5) + 1][2]
   end
end

#Now we define the inner triangles which are combinations 
inner_triangles = [[[0, 0] for _ in 1:3] for _ in 1:3]
for i in 1:3
   inner_triangles[i][1] = [inner_points[2i-1]...]
   inner_triangles[i][2] = [inner_points[2i%5]...]
   inner_triangles[i][3] = [inner_points[(i - 1) % 2 == 0 ? 3 : 5]...] 
end

#println(inner_points)
#println(outer_points)
#println(outer_triangles)
#println(inner_triangles)

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
x_range = (center[2] + outer_points[2][2]):(center[2] + outer_points[5][2])
#The the star will use all the height so the y_range doesnt matter

#RGB code colors
light_red, medium_light_red, medium_red, medium_dark_red, dark_red = 211, 204, 196, 160, 88  
#Shades from brightest to darkest
shades = [light_red, medium_light_red, medium_red, medium_dark_red, dark_red]

frame = fill(' ', terminal_size)

z_buffer = fill(Inf, terminal_size)

#Tuple containing center, outer vertex and inner vertex
keypoints = (outer_points...,inner_points...)
frame[center[1],center[2]] = 'x'

for points in keypoints
   #It is formatted (y,x)
   pos = center .- points   
   if pos[1] == 0
      pos[1] += 1
   end
   frame[pos...] = '#'
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

for i in 1:terminal_size[1]
   for j in (center[2] + outer_points[2][2]):terminal_size[2]
     rasterizeTriangle(Int16.([i, j]))
   end
end

print("\x1b[H") #Prints at the top left line
print_frame(frame, terminal_size[1],terminal_size[2])
 