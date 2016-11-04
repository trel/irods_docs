.PHONY : default get_irods doxygen mkdocs clean

SHELL = /bin/bash

MAKEGITHUBACCOUNT = irods
MAKEIRODSVERSION = master
MAKEDOXYGENVERSION = Release_1_8_14
PIPARSERVERSION = pep

IRODSTARGET = irods_for_doxygen
DOXYGENTARGET = doxygen_for_docs
VENVTARGET = venv3
PIPARSERTARGET = peps_for_docs

DOCS_SOURCE_DIR = docs

default : doxygen mkdocs
	@cp -r doxygen/* site/doxygen

get_irods :
	@echo "Getting iRODS source... v[${MAKEIRODSVERSION}]"
	@if [ ! -d ${IRODSTARGET} ] ; then git clone https://github.com/${MAKEGITHUBACCOUNT}/irods ${IRODSTARGET}; fi
	@cd ${IRODSTARGET}; git fetch; git checkout ${MAKEIRODSVERSION}; git pull --rebase

doxygen : get_irods
	@echo "Generating Doxygen..."
	@if [ ! -d ${DOXYGENTARGET} ] ; then git clone https://github.com/doxygen/doxygen ${DOXYGENTARGET}; fi
	@cd ${DOXYGENTARGET}; git checkout master; git pull; git checkout ${MAKEDOXYGENVERSION}
	@mkdir -p ${DOXYGENTARGET}/build
	@if [ ! -f ${DOXYGENTARGET}/build/CMakeCache.txt ] ; then cd ${DOXYGENTARGET}/build; cmake ..; fi
	@cd ${DOXYGENTARGET}/build ; make -j
	@cd ${IRODSTARGET}; ../${DOXYGENTARGET}/build/bin/doxygen Doxyfile 1> /dev/null
	@rsync -ar ${IRODSTARGET}/doxygen/html/ doxygen/
	@cp ${IRODSTARGET}/doxygen/custom.css doxygen/

mkdocs : get_irods
	@echo "Generating Mkdocs..."
	@./generate_icommands_md.sh
	@python generate_dynamic_peps_md.py > ${DOCS_SOURCE_DIR}/plugins/dynamic_peps_table.mdpp
	@if [ ! -d ${VENVTARGET} ] ; then virtualenv -ppython3 ${VENVTARGET}; fi
	@. ${VENVTARGET}/bin/activate; \
		pip install -r requirements.txt; \
		pushd ${DOCS_SOURCE_DIR}; \
		markdown-pp -e latexrender -o plugins/dynamic_policy_enforcement_points.md plugins/dynamic_policy_enforcement_points.mdpp; \
		mkdir -p doxygen; \
		touch doxygen/index.html; \
		popd; \
		mkdocs build --clean

peps :
	@echo "Generating Dynamic PEP information..."
	@if [ ! -d ${PIPARSERTARGET} ] ; then git clone https://github.com/xu-hao/piparser ${PIPARSERTARGET}; fi
	@cd ${PIPARSERTARGET}; git pull; git checkout ${PIPARSERVERSION}
	@cd ${PIPARSERTARGET}; \
		dist/build/piparser/piparser out auth: "*.cpp" ../{$IRODSTARGET}/plugins/auth/native/ auth_ native_auth_ resource: "*.cpp" ../irods/plugins/resources/unixfilesystem/ resource_ unix_file_ database: "db_plugin.cpp" ../irods/plugins/database/src/ db_ db_ network: "*.cpp" ../irods/plugins/network/tcp/ network_ tcp_ api: "rs*.cpp" ../irods/server/api/src/ "" rs

clean :
	@echo "Cleaning..."
	@rm -rf site
	@rm -rf ${IRODSTARGET} ${DOXYGENTARGET} ${VENVTARGET} ${PIPARSERTARGET}
	@rm -rf ${DOCS_SOURCE_DIR}/doxygen
	@rm -rf ${DOCS_SOURCE_DIR}/icommands
	@rm -rf ${DOCS_SOURCE_DIR}/plugins/rule_engine_plugin_framework.md
