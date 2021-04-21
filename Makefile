
error:
	echo "Type make<TAB><TAB> to see the available targets"


shell:
	docker-compose run --rm app /bin/bash


erase-esp32-flash:
	@docker-compose run --rm app /bin/bash -l /app/scripts/erase-esp32-flash


flash-esp32-firmware:
	@docker-compose run --rm app /bin/bash -l scripts/flash-esp32-firmware


compile-and-flash-esp32-firmware:
	@docker-compose run --rm app /bin/bash -l scripts/compile-and-flash-esp32-firmware


configure-device:
	@docker-compose run --rm app /bin/bash -l scripts/configure-device


repl:
	@docker-compose run --rm app /bin/bash -l scripts/repl

ftduino32-app:
	@docker-compose run --rm app /bin/bash -l scripts/ftduino32-setup

ftduino32: compile-and-flash-esp32-firmware ftduino32-app
