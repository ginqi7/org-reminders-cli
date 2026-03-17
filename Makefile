RELEASE_BUILD=./.build/apple/Products/Release
EXECUTABLE=reminders-sync
ARCHIVE=$(EXECUTABLE).tar.gz

.PHONY: all clean build-release package

all: build-release
	cp $(RELEASE_BUILD)/$(EXECUTABLE) .

build-release:
	swift build --configuration release --arch arm64 --arch x86_64

package: build-release
	$(RELEASE_BUILD)/$(EXECUTABLE) --generate-completion-script zsh > _$(EXECUTABLE)
	tar -pvczf $(ARCHIVE) _$(EXECUTABLE) -C $(RELEASE_BUILD) $(EXECUTABLE)
	tar -zxvf $(ARCHIVE)
	@shasum -a 256 $(ARCHIVE)
	@shasum -a 256 $(EXECUTABLE)
	rm $(EXECUTABLE) _$(EXECUTABLE)

clean:
	rm -f $(EXECUTABLE) $(ARCHIVE) _$(EXECUTABLE)
	swift package clean
