dist_man_MANS = \
	lepton-refdes_renum.1

EXTRA_DIST = \
	lepton-refdes_renum.1.in

.1.in.1:
	d=`$(GUILE) -c '(setlocale LC_ALL "C") \
	  (display (strftime "%B %-d, %Y" \
	  (car (strptime "%Y%m%d" (cadr (program-arguments))))))' $(DATE_VERSION)` ; \
	v="$(DOTTED_VERSION).$(DATE_VERSION)" ; \
	y=`echo $(DATE_VERSION)| sed -e"s/\(....\).*/\1/"`; \
	sed -e"s:[@]DATE@:$$d:" -e"s:[@]VERSION@:$$v:" -e"s:[@]YEAR@:$$y:" < $< > $@

# Rules for converting man->html
html_man_files = $(dist_man_MANS:%.1=%.html)
SUFFIXES = .1.in .1 .html

docsmandir=$(docdir)/man
dist_docsman_DATA=$(html_man_files)
if ENABLE_GROFF_HTML
.1.html:
	rm -rf $@.tmp && \
	LC_NUMERIC=C $(GROFF) -man -T html  $< >$@.tmp && \
	mv -f $@.tmp $@
else
.1.html:
	@echo "No working groff available: cannot create $@"
	@! :
endif

CLEANFILES = $(dist_man_MANS) $(html_man_files)
