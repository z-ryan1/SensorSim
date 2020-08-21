cmake_minimum_required(VERSION 3.16)
project(SensorSim CUDA C)

set(CMAKE_CUDA_STANDARD 14)

add_executable(SensorSim
        sensor/sensor_main.cu
        sensor/Sensor.cu
        Message.cu
        transport/udp_transport.cu
        transport/rdma_ud_transport.cu
        )

target_link_libraries(SensorSim pcap rdmacm ibverbs)

add_executable(ProcessorSim
        processor/processor_main.cu
        processor/Processor.cu
        Message.cu
        transport/udp_transport.cu
        transport/rdma_ud_transport.cu
        )

target_link_libraries(ProcessorSim rdmacm ibverbs)

set_target_properties(
        SensorSim
        PROPERTIES
        CUDA_SEPARABLE_COMPILATION ON)

