.PHONY: install uninstall

peekaboot:
	mkdir -p build
	cp src/peekaboot.sh build/peekaboot
	chmod +x build/peekaboot

install:
	cp build/peekaboot /usr/local/bin/

uninstall:
	rm /usr/locak/bin/peekaboot