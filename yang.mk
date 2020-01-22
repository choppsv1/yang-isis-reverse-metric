BASE := $(shell sed -e '/^\#+RFC_NAME:/!d;s/\#+RFC_NAME: *\(.*\)/\1/' $(ORG))
VERSION := $(shell sed -e '/^\#+RFC_VERSION:/!d;s/\#+RFC_VERSION: *\([0-9]*\)/\1/' $(ORG))
NEXT_VERSION := $(shell printf "$$(($(VERSION) + 1))")
PBASE := publish/$(BASE)-$(VERSION)
VBASE := draft/$(BASE)-$(VERSION)
LBASE := draft/$(BASE)-latest
SHELL := /bin/bash

# If you have docker you can avoid having to install anything by leaving this.
export DOCKRUN ?= docker run --network=host -v $$(pwd):/work labn/org-rfc
EMACSCMD := $(DOCKRUN) emacs -Q --batch --debug-init --eval '(setq org-confirm-babel-evaluate nil)' -l ./ox-rfc.el

all: $(LBASE).xml $(LBASE).txt $(LBASE).html # $(LBASE).pdf

clean:
	rm -f $(BASE).xml $(BASE)-*.{txt,html,pdf} $(LBASE).*

.PHONY: publish
publish: $(VBASE).xml $(VBASE).txt $(VBASE).html
	if [ -f $(PBASE).xml ]; then echo "$(PBASE).xml already present, increment version?"; exit 1; fi
	cp $(VBASE).xml $(VBASE).txt $(VBASE).html publish
	git add $(PBASE).xml $(PBASE).txt $(PBASE).html
	sed -i -e 's/\#+RFC_VERSION: *\([0-9]*\)/\#+RFC_VERSION: $(NEXT_VERSION)/' $(ORG)

publish-update:
	cp $(VBASE).xml $(VBASE).txt $(VBASE).html publish
	git add $(PBASE).xml $(PBASE).txt $(PBASE).html

draft:
	mkdir -p draft

$(VBASE).xml: $(ORG) ox-rfc.el test
	mkdir -p draft
	$(EMACSCMD) $< -f ox-rfc-export-to-xml
	mv $(BASE).xml $@

%-$(VERSION).txt: %-$(VERSION).xml
	$(DOCKRUN) xml2rfc --text $< > $@

%-$(VERSION).html: %-$(VERSION).xml
	$(DOCKRUN) xml2rfc --html $< > $@

%-$(VERSION).pdf: %-$(VERSION).xml
	$(DOCKRUN) xml2rfc --pdf $< > $@

$(LBASE).%: $(VBASE).%
	cp $< $@

# ------------
# Verification
# ------------

idnits: $(VBASE).txt
	if [ ! -e idnits ]; then curl -fLO 'http://tools.ietf.org/tools/idnits/idnits'; chmod 755 idnits; fi
	./idnits --verbose $<

# -----
# Tools
# -----

ox-rfc.el:
	curl -fLO 'https://raw.githubusercontent.com/choppsv1/org-rfc-export/master/ox-rfc.el'

run-test: $(ORG) ox-rfc.el
	$(EMACSCMD) $< -f ox-rfc-run-test-blocks 2>&1

test: $(ORG) ox-rfc.el
	@echo Testing $<
	@result="$$($(EMACSCMD) $< -f ox-rfc-run-test-blocks 2>&1)"; \
	if [ -n "$$(echo \"$$result\"|grep FAIL)" ]; then \
		grep RESULT <<< "$$result"; \
		exit 1; \
	else \
		grep RESULT <<< "$$result"; \
	fi;
