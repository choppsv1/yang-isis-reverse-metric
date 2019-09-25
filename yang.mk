BASE := $(shell sed -e '/^\#+RFC_NAME:/!d;s/\#+RFC_NAME: *\(.*\)/\1/' $(ORG))
VERSION := $(shell sed -e '/^\#+RFC_VERSION:/!d;s/\#+RFC_VERSION: *\([0-9]*\)/\1/' $(ORG))
VBASE := publish/$(BASE)-$(VERSION)
LBASE := publish/$(BASE)-latest

all: $(LBASE).xml $(LBASE).txt $(LBASE).html # $(LBASE).pdf

clean:
	rm -f $(BASE).xml $(BASE)-*.{txt,html,pdf} $(LBASE).*

$(VBASE).xml: $(ORG) ox-rfc.el
	emacs -Q --batch --eval '(setq org-confirm-babel-evaluate nil)' -l ./ox-rfc.el $< -f ox-rfc-export-to-xml
	mv $(BASE).xml $@

%.txt: %.xml
	xml2rfc --text -o $@ $<

%.html: %.xml
	xml2rfc --html -o $@ $<

%.pdf: %.xml
	xml2rfc --pdf -o $@ $<

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

test: $(ORG)
	@for tc in $$(awk '/^#\+NAME: test-/{print $$2}' $(ORG)); do \
	    echo Executing test block $$tc; \
	    result="$$(./run-babel-block.sh $(ORG) $$tc)"; \
	    if [ -n "$$(echo $$result|grep FAIL)" ]; then \
		printf "$$tc:FAIL:%s\n" "$$result"; \
		exit 1; \
	    fi; \
	done
