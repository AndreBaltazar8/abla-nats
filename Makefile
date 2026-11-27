ABLAC_DIR := $(abspath ../ablac)
COMPILER := $(ABLAC_DIR)/build/ablac

.PHONY: check test

check:
	mkdir -p build
	$(COMPILER) build tests/protocol_test.ab -o build/protocol-test --fast --no-cache
	build/protocol-test
	$(COMPILER) build tests/control_line_test.ab -o build/control-line-test --fast --no-cache
	build/control-line-test
	$(COMPILER) build tests/read_budget_test.ab -o build/read-budget-test --fast --no-cache
	build/read-budget-test

test: check
	ABLAC=$(COMPILER) ./tools/test-nats.sh
	ABLAC=$(COMPILER) ./tools/test-async.sh
