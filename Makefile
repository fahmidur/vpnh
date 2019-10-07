all:
	@echo 'no default target'

install:
	./install

uninstall:
	./uninstall

purge:
	./uninstall purge

.PHONY: all install uninstall purge
