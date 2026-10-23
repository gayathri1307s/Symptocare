
from copy import deepcopy


class ConversationState:

    def __init__(self):
        self.clear()

    def update(self, extracted_features):
        for disease, new_features in extracted_features.items():
            if disease not in self.features:
                self.features[disease] = {}

            self.features[disease].update(new_features)

    def get_features(self):
        return deepcopy(self.features)

    def clear(self):
        self.features = {
            "diabetes": {},
            "ckd": {},
        }
