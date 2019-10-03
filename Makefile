all:
	@echo 'no default target'

install:
	mkdir -p /var/opt/vpnh
	rm -rf   /var/opt/vpnh/co
	cp -r .  /var/opt/vpnh/co

.PHONY: all
