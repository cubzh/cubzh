
libcore.a:
	@gcc \
	-DDEBUG \
	-c *.c -I . \
	-I./../deps/libz/linux-debian-x64/include \
	-I./../../deps/lpng
	@ar rcs libcore.a *.o ./../deps/libz/linux-debian-x64/libs/libz.a

clean:
	@rm -rf *.o
	@rm -rf *.a
