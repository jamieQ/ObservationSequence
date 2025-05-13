
import Observation
import ObservationSequence
import Testing

@Observable
@MainActor
final class N {
  var value = 0

  func increment() { value += 1 }

  var squares: Observations<Int, Never> {
    Observations { self.value * self.value }
  }
}

// adjust for different sequence behaviors
let productionRate = Duration.milliseconds(250)
let consumptionRate = Duration.milliseconds(500)

@MainActor
@Test(.timeLimit(.minutes(1)))
func testproducerOutpacingConsumerBreaksObserved() async {
  let numbers = N()
  let squares = numbers.squares

  let maxIters = 10
  var observedValues: [Int] = []

  // enqueue iteration to consume sequence
  let consumingTask = Task { @MainActor in
    for await square in squares {
      print("observed value: \(square)")
      observedValues.append(square)
      try? await Task.sleep(for: consumptionRate)

      if numbers.value >= maxIters {
        break
      }
    }
    print("consumer completed")
  }

  while numbers.value < maxIters {
    print("producer incrementing value to: \(numbers.value + 1)")
    numbers.increment()
    // if production outpaces consumption, the sequence breaks
    // and no longer produces any subsequent values despite the
    // 'data source' continuing to change
    try? await Task.sleep(for: productionRate)
  }

  // wait for consumer to complete
  await _ = consumingTask.value

  #expect(true)
}
