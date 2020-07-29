cmake_minimum_required(VERSION 3.16)
project(SensorSim CUDA C)

set(CMAKE_CUDA_STANDARD 14)

add_executable(SensorSim sensor/sensor_main.cu sensor/Sensor.cu Message.cu Transport.cu)
add_executable(ProcessorSim processor/processor_main.cu processor/Processor.cu Message.cu Transport.cu)

target_link_libraries(SensorSim pcap)

set_target_properties(
        SensorSim
        PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON)

