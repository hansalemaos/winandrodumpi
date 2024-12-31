import cython
cimport cython
from struct import Struct
import io
import os
import zipfile
from subprocess import run as subprocrun
from platform import platform
cdef:
    bint iswindows = "win" in platform().lower()
    int SIG_BOOLEAN = ord("Z")
    int SIG_BYTE = ord("B")
    int SIG_SHORT = ord("S")
    int SIG_INT = ord("I")
    int SIG_LONG = ord("J")
    int SIG_FLOAT = ord("F")
    int SIG_DOUBLE = ord("D")
    int SIG_STRING = ord("R")
    int SIG_MAP = ord("M")
    int SIG_END_MAP = 0
    str PYTHON_STRUCT_UNPACK_SIG_BOOLEAN = "?"
    str PYTHON_STRUCT_UNPACK_SIG_BYTE = "b"
    str PYTHON_STRUCT_UNPACK_SIG_SHORT = "h"
    str PYTHON_STRUCT_UNPACK_SIG_INT = "i"
    str PYTHON_STRUCT_UNPACK_SIG_LONG = "q"
    str PYTHON_STRUCT_UNPACK_SIG_FLOAT = "f"
    str PYTHON_STRUCT_UNPACK_SIG_DOUBLE = "d"
    str PYTHON_STRUCT_UNPACK_SIG_STRING = "s"
    str LITTLE_OR_BIG = ">"
    object STRUCT_UNPACK_SIG_BOOLEAN = Struct(
        f"{LITTLE_OR_BIG}{PYTHON_STRUCT_UNPACK_SIG_BOOLEAN }"
    ).unpack
    object STRUCT_UNPACK_SIG_BYTE = Struct(
        f"{LITTLE_OR_BIG}{PYTHON_STRUCT_UNPACK_SIG_BYTE }"
    ).unpack
    object STRUCT_UNPACK_SIG_SHORT = Struct(
        f"{LITTLE_OR_BIG}{PYTHON_STRUCT_UNPACK_SIG_SHORT }"
    ).unpack
    object STRUCT_UNPACK_SIG_INT = Struct(
        f"{LITTLE_OR_BIG}{PYTHON_STRUCT_UNPACK_SIG_INT }"
    ).unpack
    object STRUCT_UNPACK_SIG_LONG = Struct(
        f"{LITTLE_OR_BIG}{PYTHON_STRUCT_UNPACK_SIG_LONG }"
    ).unpack
    object STRUCT_UNPACK_SIG_FLOAT = Struct(
        f"{LITTLE_OR_BIG}{PYTHON_STRUCT_UNPACK_SIG_FLOAT }"
    ).unpack
    object STRUCT_UNPACK_SIG_DOUBLE = Struct(
        f"{LITTLE_OR_BIG}{PYTHON_STRUCT_UNPACK_SIG_DOUBLE }"
    ).unpack
    dict[str,object] invisibledict={}


if iswindows:
    import subprocess
    startupinfo = subprocess.STARTUPINFO()
    startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    startupinfo.wShowWindow = subprocess.SW_HIDE
    creationflags = subprocess.CREATE_NO_WINDOW
    invisibledict = {
        "startupinfo": startupinfo,
        "creationflags": creationflags,
        "start_new_session": True,
    }

cdef list parsedata(
    bytes sbytes,
):
    cdef:
        list resultlist = []
        object restofstringasbytes = io.BytesIO(sbytes)
        object restofstringasbytes_read=restofstringasbytes.read
        int ordnextbyte
        object nextbyte
    while nextbyte := restofstringasbytes_read(1):
        try:
            ordnextbyte = ord(nextbyte)
            if ordnextbyte == SIG_STRING:
                bytes2convert2 = restofstringasbytes_read(2)
                bytes2convert = restofstringasbytes_read(
                    bytes2convert2[len(bytes2convert2) - 1]
                )
                resultlist.append(bytes2convert.decode("utf-8", errors="ignore"))
            elif ordnextbyte == SIG_SHORT:
                bytes2convert = restofstringasbytes_read(2)
                resultlist.append( STRUCT_UNPACK_SIG_SHORT(bytes2convert)[0])
            elif ordnextbyte == SIG_BOOLEAN:
                bytes2convert = restofstringasbytes_read(1)
                resultlist.append( STRUCT_UNPACK_SIG_BOOLEAN(bytes2convert)[0])

            elif ordnextbyte == SIG_BYTE:
                bytes2convert = restofstringasbytes_read(1)
                resultlist.append(STRUCT_UNPACK_SIG_BYTE(bytes2convert)[0])

            elif ordnextbyte == SIG_INT:
                bytes2convert = restofstringasbytes_read(4)
                resultlist.append( STRUCT_UNPACK_SIG_INT(bytes2convert)[0])

            elif ordnextbyte == SIG_FLOAT:
                bytes2convert = restofstringasbytes_read(4)
                resultlist.append(STRUCT_UNPACK_SIG_FLOAT(bytes2convert)[0])

            elif ordnextbyte == SIG_DOUBLE:
                bytes2convert = restofstringasbytes_read(8)
                resultlist.append(STRUCT_UNPACK_SIG_DOUBLE(bytes2convert)[0])

            elif ordnextbyte == SIG_LONG:
                bytes2convert = restofstringasbytes_read(8)
                resultlist.append(STRUCT_UNPACK_SIG_LONG(bytes2convert)[0])
        except Exception as e:
            pass
    return resultlist

cdef list[tuple] extract_files_from_zip(object zipfilepath):
    cdef:
        bytes data=b""
        object ioby
        list[tuple] single_files_extracted
        Py_ssize_t len_single_files, single_file_index
    if isinstance(zipfilepath, str) and os.path.exists(zipfilepath):
        with open(zipfilepath, "rb") as f:
            data = f.read()
    else:
        data = zipfilepath
    ioby = io.BytesIO(data)
    single_files_extracted = []
    with zipfile.ZipFile(ioby, "r") as zip_ref:
        single_files = zip_ref.namelist()
        len_single_files = len(single_files)
        for single_file_index in range(len_single_files):
            try:
                single_files_extracted.append(
                    (
                        single_files[single_file_index],
                        zip_ref.read(single_files[single_file_index]),
                    )
                )
            except Exception:
                pass
                #errwrite()
    return single_files_extracted

def parse_window_elements(
    object dump_cmd='cmd window dump-visible-window-views',
    **kwargs
):
    cdef:
        object myproc
        bytes zipfilepath
        list[tuple] zipname_zipdata
        Py_ssize_t zip_index
        list[dict] result_dicts
    myproc=subprocrun(dump_cmd,**{**invisibledict,**kwargs,**{'capture_output':True}})
    if iswindows:
        zipfilepath = myproc.stdout.replace(b"\r\n", b"\n")
    else:
        zipfilepath =  myproc.stdout
    zipname_zipdata = extract_files_from_zip(zipfilepath)
    result_dicts=[]
    for zip_index in range(len(zipname_zipdata)):
        try:
            result_dicts.append(parse_wm_window_dump(zipname_zipdata[zip_index][1],zipname_zipdata[zip_index][0]))
        except Exception:
            pass
    return result_dicts

cdef dict parse_wm_window_dump(bytes data, str parsed_window):
    cdef:
        list a,allobject,mapping
        Py_ssize_t numberofid, iax,ini,ini2
        dict lookupdict_reverse
        list[list] allobs = [[]]
        bint waitingforvalue = False
        dict resultsasdict = {}
        Py_ssize_t inicounter = 0
        set allpossiblekeys = set()
    a = parsedata(sbytes=data)
    numberofid = a.index("propertyIndex")
    allobject = a[:numberofid]
    mapping = a[numberofid + 1 :]
    lookupdict_reverse = dict(zip(mapping, mapping[1:]))
    for iax in range(len(allobject)):
        try:
            if isinstance(allobject[iax], int) and allobject[iax] in lookupdict_reverse:
                allobs[len(allobs) - 1].append([lookupdict_reverse[allobject[iax]]])
                waitingforvalue = True
            else:
                if waitingforvalue:
                    (
                        allobs[len(allobs) - 1][
                            len(allobs[len(allobs) - 1]) - 1
                        ].append(allobject[iax])
                    )
                    waitingforvalue = False
                else:
                    allobs.append([])
        except Exception as e:
            pass
    for ini in range(len(allobs)):
        if allobs[ini]:
            resultsasdict[inicounter] = {}
            for ini2 in range(len(allobs[ini])):
                if len(allobs[ini][ini2]) == 2:
                    resultsasdict[inicounter][allobs[ini][ini2][0]] = allobs[ini][ini2][
                        1
                    ]
                    allpossiblekeys.add(allobs[ini][ini2][0])
            inicounter += 1

    for k in resultsasdict:
        for posskey in allpossiblekeys:
            if posskey not in resultsasdict[k]:
                resultsasdict[k][posskey] = None
        resultsasdict[k]["PARSED_WINDOW"]=parsed_window
    return resultsasdict

