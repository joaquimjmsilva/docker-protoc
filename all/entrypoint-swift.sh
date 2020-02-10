#!/bin/bash -e

printUsage() {
    echo "gen-proto generates grpc and protobuf @ Namely"
    echo " "
    echo "Usage: gen-proto -f my-service.proto -l go"
    echo " "
    echo "options:"
    echo " -h, --help                     Show help"
    echo " -f FILE                        The proto source file to generate"
    echo " -d DIR                         Scans the given directory for all proto files"
    echo " -l LANGUAGE                    The language to generate (${SUPPORTED_LANGUAGES[@]})"
    echo " -o DIRECTORY                   The output directory for generated files. Will be automatically created."
    echo " -i includes                    Extra includes"
    echo " --lint CHECKS                  Enable linting protoc-lint (CHECKS are optional - see https://github.com/ckaznocha/protoc-gen-lint#optional-checks)"
    echo " --with-docs FORMAT             Generate documentation (FORMAT is optional - see https://github.com/pseudomuto/protoc-gen-doc#invoking-the-plugin)"
}


GEN_GATEWAY=false
GEN_DOCS=false
GEN_VALIDATOR=false
VALIDATOR_SUPPORTED_LANGUAGES=()
DOCS_FORMAT="html,index.html"
GEN_TYPESCRIPT=false
LINT=false
LINT_CHECKS=""
SUPPORTED_LANGUAGES=("swift")
EXTRA_INCLUDES=""
OUT_DIR=""
GO_SOURCE_RELATIVE=""
GO_PACKAGE_MAP=""
GO_PLUGIN="grpc"
GO_VALIDATOR=false
NO_GOOGLE_INCLUDES=false
DESCR_INCLUDE_IMPORTS=false
DESCR_INCLUDE_SOURCE_INFO=false
DESCR_FILENAME="descriptor_set.pb"
CSHARP_OPT=""

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            printUsage
            exit 0
            ;;
        -f)
            shift
            if test $# -gt 0; then
                FILE=$1
            else
                echo "no input file specified"
                exit 1
            fi
            shift
            ;;
        -d)
            shift
            if test $# -gt 0; then
                PROTO_DIR=$1
            else
                echo "no directory specified"
                exit 1
            fi
            shift
            ;;
        -l)
            shift
            if test $# -gt 0; then
                GEN_LANG=$1
            else
                echo "no language specified"
                exit 1
            fi
            shift
            ;;
        -o) shift
            OUT_DIR=$1
            shift
            ;;
        -i) shift
            EXTRA_INCLUDES="$EXTRA_INCLUDES -I$1"
            shift
            ;;
        --with-docs)
            GEN_DOCS=true
            if [ "$#" -gt 1 ] && [[ $2 != -* ]]; then
                DOCS_FORMAT=$2
                shift
            fi
            shift
            ;;
        --lint)
            LINT=true
            if [ "$#" -gt 1 ] && [[ $2 != -* ]]; then
                LINT_CHECKS=$2
		        shift
            fi
            shift
            ;;
        *)
            break
            ;;
    esac
done

if [[ -z $FILE && -z $PROTO_DIR ]]; then
    echo "Error: You must specify a proto file or proto directory"
    printUsage
    exit 1
fi

if [[ ! -z $FILE && ! -z $PROTO_DIR ]]; then
    echo "Error: You may specifiy a proto file or directory but not both"
    printUsage
    exit 1
fi

if [ -z $GEN_LANG ]; then
    echo "Error: You must specify a language: ${SUPPORTED_LANGUAGES[@]}"
    printUsage
    exit 1
fi

if [[ ! ${SUPPORTED_LANGUAGES[*]} =~ "$GEN_LANG" ]]; then
    echo "Language $GEN_LANG is not supported. Please specify one of: ${SUPPORTED_LANGUAGES[@]}"
    exit 1
fi

if [[ $OUT_DIR == '' ]]; then
    GEN_DIR="gen"
    OUT_DIR="${GEN_DIR}/pb-$GEN_LANG"
fi

if [[ ! -d $OUT_DIR ]]; then
    mkdir -p $OUT_DIR
fi

GEN_STRING=''
case $GEN_LANG in
    "swift")
        GEN_STRING="--swift_out=$OUT_DIR --plugin=protoc-gen-swift=`which protoc-gen-swift`"
        ;;
    *)
        GEN_STRING="--grpc_out=$OUT_DIR --${GEN_LANG}_out=$OUT_DIR --plugin=protoc-gen-grpc=`which grpc_${PLUGIN_LANG}_plugin`"
        ;;
esac

if [[ $GEN_DOCS == true ]]; then
    mkdir -p $OUT_DIR/doc
    GEN_STRING="$GEN_STRING --doc_opt=$DOCS_FORMAT --doc_out=$OUT_DIR/doc"
fi

LINT_STRING=''
if [[ $LINT == true ]]; then
    if [[ $LINT_CHECKS == '' ]]; then
        LINT_STRING="--lint_out=."
    else
        LINT_STRING="--lint_out=$LINT_CHECKS:."
    fi
fi

PROTO_INCLUDE=""
if [[ $NO_GOOGLE_INCLUDES == false ]]; then
  PROTO_INCLUDE="-I /opt/include"
fi

PROTO_INCLUDE="$PROTO_INCLUDE $EXTRA_INCLUDES"

if [ ! -z $PROTO_DIR ]; then
    PROTO_INCLUDE="$PROTO_INCLUDE -I $PROTO_DIR"
    FIND_DEPTH=""
    PROTO_FILES=(`find ${PROTO_DIR} ${FIND_DEPTH} -name "*.proto"`)
else
    PROTO_INCLUDE="-I . $PROTO_INCLUDE"
    PROTO_FILES=($FILE)
fi

protoc $PROTO_INCLUDE \
    $GEN_STRING \
    $LINT_STRING \
    ${PROTO_FILES[@]}

