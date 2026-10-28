int stepCount = 1;

void stepStart(String title) {
  print('------------------------------------------------');
  print('$stepCount: $title');
  stepCount++;
}

void stepStop() {
  print('================================================');
}

void substep(String subTitle) {
  print(' $subTitle');
}
