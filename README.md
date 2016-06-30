# Speech.framework в iOS 10
---
Очередная конференция очередные новшества. Судя по настроениям нас ждет отмена клавиатур и устройств ввода. Мой коллега, Геор Касапиди уже описал для вас возможности Siri в своей статье <#статья#>. К слову сказать, было забавно наблюдать в офисе за его исследованиями: “Сири, отправь сообщение с помощью <моя программа> Привет, как дела”. Но видно скоро мы будем писать и код для программ так же, а инициировать компиляцию: “Сири, собери мне билд”…

С появлением iOS 10 и SiriKit Apple представили нам впервые Speech.framework. Документация по нему не особо богата, да и сам фреймворк не особо большой. Но что заинтересовало меня, так это возможность распознания речи как реально произносимой сейчас, так и записанной. Что же, давайте посмотрим на это.

### Авторизация
---
В статье расмотрим работу по распознанию речи в прямом эфире. По этому нам потребуются две авторизации. Одна - это разрешение пользователя работать с распознанием речи, вторая - это доступ к микророфону.  

![](https://habrastorage.org/files/676/c33/f6f/676c33f6f63e4738acb14018049aa300.PNG)

Оба запроса должны быть оформлены специальными ключами в .plist файле с описанием назначения, зачем приложениею требуется доступ к ним. Это важно, потому как без них нас ждет неминуемый крэш.

- микрофон: NSMicrophoneUsageDescription
- распознание речи: NSSpeechRecognitionUsageDescription

![](https://habrastorage.org/files/75a/d6f/56d/75ad6f56d29c43b2a94ddc85d26691a2.png)


Далее нам необходимо обработать статус авторизации
```objc
- (void)handleAuthorizationStatus:(SFSpeechRecognizerAuthorizationStatus)s {
  switch (s) {
    case SFSpeechRecognizerAuthorizationStatusNotDetermined:
    //  система еще не запрашивала доступ у пользователя
      [self requestAuthorization];
      break;
    case SFSpeechRecognizerAuthorizationStatusDenied:
    //  пользователь запретил доступ
      [self informDelegateErrorType:(EVASpeechManagerErrorSpeechRecognitionDenied)];
      break;
    case SFSpeechRecognizerAuthorizationStatusRestricted:
      // TODO: неизведанное состояние. исследовать позже
      break;
    case SFSpeechRecognizerAuthorizationStatusAuthorized: {
      //  можно работать
    }
      break;
  }
}
```

если требуется, запросить авторизацию у пользователя
```objc
- (void)requestAuthorization {
  __weak typeof(self) weakSelf = self;
  [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
    __strong typeof(weakSelf) strongSelf = weakSelf;
    [strongSelf handleAuthorizationStatus:status];
  }];
}
```

# Настройка
---
Для успешной работы по распознанию речи нам потребуется четыре объекта
``` objc
@property SFSpeechRecognizer *recognizer;
@property AVAudioEngine *audioEngine;
@property (nonatomic) SFSpeechAudioBufferRecognitionRequest *request;
@property SFSpeechRecognitionTask *currentTask;
```

и подписаться на протокол 
``` objc
@interface EVASpeechManager () <SFSpeechRecognitionTaskDelegate>
```
У speech.framework сам по себе не работает с получением звука от пользователя, по этому нам надо взаимодействовать с AVFoundation.framework и настроить AVAudioEngine. Далее в статье мы увидим для чего это необходимо.
``` objc
    self.audioEngine = [[AVAudioEngine alloc] init];
    AVAudioInputNode *node = self.audioEngine.inputNode;
    AVAudioFormat *recordingFormat = [node outputFormatForBus:bus];
    __weak typeof(self) weakSelf = self;
    [node installTapOnBus:bus
               bufferSize:1024
                   format:recordingFormat
                    block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
                      __strong typeof(weakSelf) strongSelf = weakSelf;
                      [strongSelf.request appendAudioPCMBuffer:buffer];
                    }];
```

# Использование
---
После успешной настройки нашего менеджера речи мы можем приступить к самой работе. 
Мы создаем реквест на распознание 
``` objc
self.request = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
```
и перед тем, как мы отдадим его на распознание, мы должны включить прослушку аудио потока
``` objc
- (void)performRecognize {
  [self.audioEngine prepare];
  NSError *error = nil;
  if ([self.audioEngine startAndReturnError:&error]) {
    self.currentTask = [self.recognizer recognitionTaskWithRequest:self.request
                                                          delegate:self];
  } else {
    [self informDelegateError:error];
  }
}
```
Приняв запрос, наш менеджер вернет нам объект задачи (task). Далее мы будем управлять уже этим объектом.

Важно помнить, что запустив задачу (task) на распознание мы не можем запустить ее еще раз, пока не остановим. Т.е. если мы начали выполнение запроса, нам надо его и остановить. Иначе мы получим крэш 
“reason: 'SFSpeechAudioBufferRecognitionRequest cannot be re-used’”

``` objc
- (void)stopRecognize {
  if ([self isTaskInProgress]) {
    [self.currentTask finish];
    [self.audioEngine stop];
  }
}
```
Для остановки задачи есть два способа
- отмена (cancel)
- окончание (finish)

разница в том, что при отмене (cancel) мы не получим окончательной обработки данных, а только то, что было на момент отмены. При окончании (finish) речь будет распознана полностью. Speech.framework для распознания речи использует Siri движок. Данные отправляются/принимаются через сеть в асинхронном режиме. По этому окончательный результат распознания может иметь задержку.

# Ошибки
---
За время работы с приложением я столкнулся с ошибками:
- Error: SessionId=com.siri.cortex.ace.speech.session.event.SpeechSessionId@439e90ed, Message=Timeout waiting for command after 30000 ms
- Error: SessionId=com.siri.cortex.ace.speech.session.event.SpeechSessionId@714a717a, Message=Empty recognition

первая ошибка прилетела когда после небольшой диктовке речь была закончена, а рекогнайзер продолжал работу;
вторая ошибка прилетела, когда рекогнайзер не получил никакого аудио потока и распознание было отменено пользователем.
Обе ошибки были пойманы в методе делегата
``` objc
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishSuccessfully:(BOOL)successfully {
  if (!successfully) {
    // ошибки здесь
  }
}
```
