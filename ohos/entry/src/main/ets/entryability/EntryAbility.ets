/*
* Copyright (c) 2023 Hunan OpenValley Digital Industry Development Co., Ltd.
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import {
  BasicMessageChannel,
  BinaryCodec,
  ByteBuffer,
  FlutterAbility,
  FlutterEngine,
  StandardMessageCodec,
  TaskQueueOptions
} from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

export default class EntryAbility extends FlutterAbility {
  private byteBufferCache: ByteBuffer | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    const reset = new BasicMessageChannel<Object>(
      flutterEngine.getDartExecutor(),
      "dev.flutter.echo.reset",
      StandardMessageCodec.INSTANCE
    );
    reset.setMessageHandler({
      onMessage: (_, __) => {
        this.byteBufferCache = null;
      }
    })

    const basicStandard = new BasicMessageChannel<Object>(
      flutterEngine.getDartExecutor(),
      "dev.flutter.echo.basic.standard",
      StandardMessageCodec.INSTANCE
    );
    basicStandard.setMessageHandler({
      onMessage: (message, reply) => {
        reply.reply(message);
      }
    })

    const basicBinary = new BasicMessageChannel<Object>(
        flutterEngine.getDartExecutor(),
        "dev.flutter.echo.basic.binary",
        BinaryCodec.INSTANCE_DIRECT
    );

    basicBinary.setMessageHandler({
      onMessage: (message, reply) => {
        reply.reply(message);
      }
    })

    const taskQueue = flutterEngine.getDartExecutor().makeBackgroundTaskQueue(new TaskQueueOptions());
    const backgroundStandard = new BasicMessageChannel<Object>(
        flutterEngine.getDartExecutor(),
        "dev.flutter.echo.background.standard",
        StandardMessageCodec.INSTANCE,
        taskQueue
    );

    backgroundStandard.setMessageHandler({
      onMessage: (message, reply) => {
        reply.reply(message);
      }
    })
  }
}
