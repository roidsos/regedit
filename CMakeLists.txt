cmake_minimum_required(VERSION 3.13)
project(HiveEdit)

# Enable AddressSanitizer
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -fsanitize=address -fno-omit-frame-pointer")

file(GLOB_RECURSE CC_FILES
    "src/*.c"
    "src/*.cpp"
)

add_executable(hive-edit ${CC_FILES})
target_link_options(hive-edit PUBLIC -fsanitize=address)