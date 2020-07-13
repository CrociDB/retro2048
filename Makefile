all: dos bootsector-dos bootsector

dos:
	nasm -f bin -o r2048.com main.asm -Ddos=1

bootsector-dos:
	nasm -f bin -o b2048.com main.asm

bootsector:
	nasm -f bin -o b2048.bin main.asm -Dbootsector=1
	wc -c b2048.bin

clear:
	rm r2048.bin b2048.com b2048.bin
