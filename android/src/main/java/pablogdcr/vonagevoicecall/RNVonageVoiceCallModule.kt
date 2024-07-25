package pablogdcr.vonagevoicecall

import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class RNVonageVoiceCallModule : Module() {
  override fun definition() = ModuleDefinition {
    Name("RNVonageVoiceCall")

    // // Sets constant properties on the module. Can take a dictionary or a closure that returns a dictionary.
    // Constants(
    //   "PI" to Math.PI
    // )

    // // Defines event names that the module can send to JavaScript.
    // Events("onChange")

    // Defines a JavaScript synchronous function that runs the native code on the JavaScript thread.
    Function("hello") {
      "Hello world! 👋"
    }

    // // Defines a JavaScript function that always returns a Promise and whose native code
    // // is by default dispatched on the different thread than the JavaScript runtime runs on.
    // AsyncFunction("setValueAsync") { value: String ->
    //   // Send an event to JavaScript.
    //   sendEvent("onChange", mapOf(
    //     "value" to value
    //   ))
    // }

    // // Enables the module to be used as a native view. Definition components that are accepted as part of
    // // the view definition: Prop, Events.
    // View(RNVonageVoiceCallView::class) {
    //   // Defines a setter for the `name` prop.
    //   Prop("name") { view: RNVonageVoiceCallView, prop: String ->
    //     println(prop)
    //   }
    // }
  }
}
