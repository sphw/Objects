Objects
========
  
Objects is a simple model layer for your iOS apps. It handles REST requests, object caching, and file caching. It's goal is to strike a balance between configuration heavy tools and dogmatic ones. For local storage it use Couchbase Lite 2.0. REST requests can be routed through anyserver that can serialize to msgpack. 
# Setup
## Requirments
- iOS 9.0+

## Installation
You can install objects with Carthage. Cocoapods is coming soon (but seriously switch already).

```
github 'sphw/Objects' ~> 0.9
```


# Usage
## Server Requirments

Objects relies on a simplified version of REST to interact with servers. It only uses 5 verbs (ok thats more than REST but you need these): Push, Pull, Delete, Search.  

- Push creates or updates an object 
- Pull downloads an object by a given ID
- Delete deletes an object
- Search searches for an object

Endpoints for each of the verbs are as follows

- Push *POST*: <API URL>/<Object Singular>/
- Pull *GET*:  <API URL>/<Object Singular>/<Object ID>
- Delete *DELETE*: <API URL>/<Object Singular>/
- Search *GET* <API URL>/<Object Singular>/<Search Term>

Data is sent and recieved in a slightly asymetric format, both ways are serialized in msgpack map format.

### Recieve
#### Singular Request

```json
{
  "object": <Map of object properties>,
  "<Dependency plural>": [
  <Map of dependency>,
  <Map of dependency>,
  ...
  ],
  ...
}
```
#### Plural Request

```json
{
  "objects": [
    <Map of object properties>,
    ...
  ],
  "<Dependency plural>": [
  <Map of dependency>,
  ...
  ],
  ...
}
```
### Send

The map you recieve in the "object" property is in the same format you will be sending to the server.

```json
{
  "<Property Name>": <Value>
  "<Dependency Name Plural>": [
    "<Id 1>", "<Id 2>", "<Id n>"
  ]
}
```
Updates to dependency lists will need to be taken care of by the server. 
## Client Requirments
### Setup
The first step to setting up Objects is to configure the DataManager. We try and leave as much up to you as possible. You supply your own class from string methods, Couchbase database, api url, and current user.
Add something like this to your AppDelegate
```swift
DataManager.shared.database = CBLDatabase(name: "foo", error: nil)
DataManager.shared.apiURL = "https://foo.io/api/v1/"
```
Next you have to have a class for your user that complies with the UserType protocol. That means it needs a variable called cookie that is a dictionary of Strings and Strings. This will include the headers that will be passed along with every request.

```swift
DataManager.shared.currentUser = {User.current}
```

Instead of using Objective C's reflection capabilities Objects uses a slightly more flexiable version. You must define a struct, class, or enum that complies with ClassesType.

```swift
protocol ClassesType {
    func type(from json: [String: Any]) -> Object?
    static func from(singular: String) -> Self?
    static func from(plural: String) -> Self?
}
```

Here is an example implementation.

```swift
enum Classes: ClassesType {
    case Activity, User
    func type(from json: [String: Any]) -> Object? {
        switch self {
        case .Activity: return Ascent.Activity(dictionary: json, add: false)
        case .User: return Ascent.User(dictionary: json, add: false)
        }
    }
    func from(singular: String) -> Classes? {
        switch singular {
        case "activity": return .Activity
        case "user": return .User
        default: return nil
        }
    }
    func from(plural: String) -> Classes? {
        switch plural {
        case "activities": return .Activity
        case "users": return .User
        default: return nil
        }
    }
}

```

Then set the Classes property on DataManager

```swift
DataManager.shared.Classes = Classes.User
```

Then all thats left is to subclass Object, add it to your Classes enum, and add some properties. You must add these functions

```swift
    override init(){
        super.init()
    }
    required init?(dictionary: [String : Any]?, add: Bool = true) {
        super.init()
        guard let dictionary = dictionary,
            self.load(dictionary: dictionary) == true else { return nil }
        self.document = DataManager.shared.database.document(withID: self.id.value)
        imageURL.ignoreNil().observableMap({self.file(name: "image", url: $0)}).ignoreNil().ignoreNil().map({UIImage.init(data: $0)}).bind(to: image)
        if add {
            DataManager.shared.add(self)
        }
    }
```

Its recomended that you add implementations of these functions as well

```swift
    override func load(dictionary: [String: Any]) -> Bool
    override var dictionary: [String : Any] {
```
