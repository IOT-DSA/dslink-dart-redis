import "dart:convert";

import "package:redis_client/redis_client.dart";
import "package:dslink/client.dart";
import "package:dslink/responder.dart";

SimpleNodeProvider provider;
LinkProvider link;
RedisClient redis;

main(List<String> args) async {
  redis = await RedisClient.connect("127.0.0.1:6379");
  link = new LinkProvider(
    args,
    "Redis-",
    isResponder: true,
    isRequester: false,
    defaultNodes: {
      "Set": {
        r"$invokable": "write",
        r"$is": "set",
        r"$result": "values",
        r"$params": [
          {
            "name": "key",
            "type": "string"
          },
          {
            "name": "value",
            "type": "string"
          }
        ],
        r"$columns": [
          {
            "name": "success",
            "type": "bool"
          }
        ]
      },
      "Get": {
        r"$invokable": "write",
        r"$is": "get",
        r"$result": "values",
        r"$params": [
          {
            "name": "key",
            "type": "string"
          }
        ],
        r"$columns": [
          {
            "name": "success",
            "type": "bool"
          },
          {
            "name": "value",
            "type": "dynamic"
          }
        ]
      }
    },
    profiles: {
      "get": (String path) => new GetNode(path),
      "set": (String path) => new SetNode(path)
    }
  );

  link.connect();
}

class SetNode extends SimpleNode {
  SetNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    if (params["key"] == null) return {
      "success": false
    };

    var key = params["key"];
    var value = params["value"];

    try {
      await redis.set(key, valueToString(value));
    } catch (e) {
      return {
        "success": false
      };
    }

    return {
      "success": true
    };
  }
}

class GetNode extends SimpleNode {
  GetNode(String path) : super(path);

  @override
  onInvoke(Map<String, dynamic> params) async {
    if (params["key"] == null) {
      return {
        "success": false,
        "value": null
      };
    }

    var key = params["key"];

    try {
      var value = stringToValue(await redis.get(key));
      print(value);
      return {
        "success": true,
        "value": value
      };
    } catch (e) {
      return {
        "success": false,
        "value": null
      };
    }
  }
}

String valueToString(input) {
  if (input == null) {
    return "null";
  }

  if (input is String) {
    return input;
  } else if (input is Map || input is List) {
    return JSON.encode(input);
  } else {
    return input.toString();
  }
}

dynamic stringToValue(String input) {
  if (input == null || input == "null") {
    return null;
  }

  var i = num.parse(input, (source) => null);

  if (i != null) {
    return i;
  }

  try {
    return JSON.decode(input);
  } catch (e) {
    return input;
  }
}
