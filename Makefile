all:
	cd cpu/riscv && make build_sim
	cp ./cpu/riscv/testspace/test code