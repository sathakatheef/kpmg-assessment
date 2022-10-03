import json
import os

def _utl_sort_list_by_attr(list, attr_name):
    """ Sorts list of dictionaries that have the same set of keys by one of the keys
    """
    return sorted(list, key=lambda x: x[attr_name])


def _utl_print_list_csv(list, file=None, file_append=False, use_stdout=True):
    """ Prints list of dictionaries that have the same set of keys + header row with keys (as column names)
        Optionally can write to a file if specificed. 
        For file writing, if Append flag =true, it will append to the file.
    """
    if len(list) > 0:
        if use_stdout:
            # header
            print(",".join(map(str, list[0].keys())))
            #rows
            for x in list:
                print(",".join(map(str, x.values())))

        if file:
            if os.path.exists(file) and file_append:
                # appending to existing file
                access_type='a'
            else:
                # creating a new file
                access_type='w'

            try:
                file_object = open(file, access_type)
                # do not write header if we are appending to the existing file
                if access_type == 'w':
                    file_object.write(",".join(map(str, list[0].keys())))
                    file_object.write("\n")
                for x in list:
                    file_object.write(",".join(map(str, x.values())))
                    file_object.write("\n")
            except Exception as err:
                print (str(err))
            finally:
                file_object.close()        

    return True

def jprint(json_doc):
    """
    Prints dict as beautified JSON
    """
    print(json.dumps(json_doc, indent=4, default=str))