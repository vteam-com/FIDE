int stepCount = 1;

void stepStart(final String title) {
  print('------------------------------------------------');
  print('$stepCount: $title');
  stepCount++;
}

void stepStop() {
  print('================================================');
}

void substep(final String subTitle) {
  print(' $subTitle');
}
