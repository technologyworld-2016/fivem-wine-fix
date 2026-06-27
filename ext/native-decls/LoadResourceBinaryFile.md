---
ns: CFX
apiset: shared
---
## LOAD_RESOURCE_BINARY_FILE

```c
object LOAD_RESOURCE_BINARY_FILE(char* resourceName, char* fileName);
```

Reads the binary content of a file in a specified resource.
If executed on the client, this file has to be included in `files` in the resource manifest.

Because in Lua and JS strings can contain null bytes, in those runtimes this native is equivalent to [`LOAD_RESOURCE_FILE`](#_0x76A9EE1F). In C# strings are null-terminated and this native is the only way to read a binary file client-side.

## Parameters
* **resourceName**: The resource name.
* **fileName**: The file in the resource.

## Return value
The file contents as a string in Lua/JS and byte[] in C#. Returns an empty string/array if the file does not exist.

## Examples

```lua
local contents = LoadResourceBinaryFile(GetCurrentResourceName(), "test.png")

if #contents == 0 then
    print("File not found or empty.")
    return
end

print("Loaded " .. #contents .. " bytes from test.png")
-- In Lua this will be a string
print(contents)  -- Print the raw byte array
```

```js
let fileContent = LoadResourceBinaryFile(GetCurrentResourceName(), 'test.png');
console.log('Binary file content length:', fileContent.length);
// In JS this will be a string
console.log('File content as string:', fileContent);
console.log('File type:', typeof fileContent);
```

```cs
// In C# this will be a dynamic that can be cast to byte[]
 byte[] binaryContents = (byte[])LoadResourceBinaryFile("mono-test", "test.png");
if(binaryContents.Length > 0)
{
    Debug.WriteLine($"Successfully loaded binary resource: {binaryContents.Length} bytes");
    // Print as an UTF-8 string, replacing null characters with "\0" for visibility in the console
    Debug.WriteLine(System.Text.Encoding.UTF8.GetString(binaryContents, 0, binaryContents.Length).Replace("\0", "\\0"));
}
else
{
    Debug.WriteLine("Failed to load binary resource or resource is empty.");
}
```