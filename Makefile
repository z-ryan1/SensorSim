CXXCUDA=/usr/bin/nvcc
LIBS = -libverbs -lrdmacm -lcuda -lpcap

all: sensor-debug

processor-debug: processor/Processor.cu processor/processor_main.cu transport/rdma_ud_transport.cu transport/udp_transport.cu
	$(CXXCUDA) -g -o  -o bin/processor-debug.out processor/Processor.cu processor/processor_main.cu transport/rdma_ud_transport.cu transport/udp_transport.cu $(LIBS)


sensor-debug: sensor/sensor_main.cu sensor/Sensor.cu transport/rdma_ud_transport.cu transport/udp_transport.cu
	$(CXXCUDA) -g -o bin/sensor-debug.out sensor/sensor_main.cu sensor/Sensor.cu transport/rdma_ud_transport.cu transport/udp_transport.cu $(LIBS)

clean:
	rm bin/*
