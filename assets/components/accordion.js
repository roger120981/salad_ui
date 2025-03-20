// saladui/components/accordion.js
import Component from "../core/component";
import CollectionManager from "../core/collection-manager";
import SaladUI from "../index";

/**
 * AccordionItem class to manage individual accordion items
 * Handles state transitions and events for a single accordion item
 */
class AccordionItem extends Component {
  constructor(itemElement, parentComponent, options) {
    const { initialState = "closed" } = options || {};
    super(itemElement, { initialState, ignoreItems: false });
    this.parent = parentComponent;
    this.value = itemElement.dataset.value;
    this.disabled = itemElement.dataset.disabled === "true";

    this.trigger = itemElement.querySelector("[data-part='item-trigger']");
    this.content = itemElement.querySelector("[data-part='item-content']");
    this.initialize();
    this.setupEvents();
  }

  getComponentConfig() {
    return {
      stateMachine: {
        closed: {
          transitions: {
            open: "open",
          },
        },
        open: {
          transitions: {
            close: "closed",
          },
        },
      },
      events: {
        closed: {
          mouseMap: {
            "item-trigger": {
              click: "handleTriggerActivation",
            },
          },
          keyMap: {
            Enter: "handleTriggerActivation",
            " ": "handleTriggerActivation",
          },
        },
        open: {
          mouseMap: {
            "item-trigger": {
              click: "handleTriggerActivation",
            },
          },
          keyMap: {
            Enter: "handleTriggerActivation",
            " ": "handleTriggerActivation",
          },
        },
      },
      visibilityConfig: {
        closed: {
          "item-content": true,
        },
        open: {
          "item-content": false,
        },
      },
      ariaConfig: {
        "item-trigger": {
          all: {
            controls: () => this.content?.id,
          },
          open: {
            expanded: "true",
          },
          closed: {
            expanded: "false",
          },
        },
        "item-content": {
          all: {
            labelledby: () => this.trigger?.id,
          },
        },
      },
    };
  }

  initialize() {
    if (this.disabled) {
      this.trigger.setAttribute("tabindex", "-1");
    } else {
      this.trigger.setAttribute("tabindex", "0");
    }
  }

  handleEvent(eventType) {
    switch (eventType) {
      case "select":
        return this.transition("open");
      case "unselect":
        return this.transition("close");
      case "focus":
        if (this.trigger && !this.disabled) {
          this.trigger.focus();
        }
        return true;
      case "blur":
        return true;
    }
  }

  handleTriggerActivation(event) {
    event.preventDefault();
    if (!this.disabled && !this.parent.disabled) {
      this.parent.toggleItem(this);
    }
  }
}

/**
 * AccordionComponent class for SaladUI framework
 * Manages a collection of accordion items with state transitions
 */
class AccordionComponent extends Component {
  constructor(el, hookContext) {
    super(el, { hookContext });

    // Initialize properties
    this.type = this.options.type || "single";
    this.disabled = this.options.disabled || false;

    // Initialize collection manager
    this.collectionManager = new CollectionManager({
      type: this.type,
      defaultValue: this.options.defaultValue,
      value: this.options.value,
      getItemValue: (item) => item.value,
      isItemDisabled: (item) => item.disabled || this.disabled,
    });

    // Set keyboard navigation defaults
    this.config.preventDefaultKeys = [
      "ArrowUp",
      "ArrowDown",
      "Home",
      "End",
      "Enter",
      " ",
    ];

    // Initialize accordion items
    this.initializeItems();
  }

  getComponentConfig() {
    return {
      stateMachine: {
        idle: {
          enter: () => {},
          exit: () => {},
          transitions: {},
        },
      },
      events: {
        idle: {
          keyMap: {
            ArrowUp: () => this.navigateItem("prev"),
            ArrowDown: () => this.navigateItem("next"),
            Home: () => this.navigateItem("first"),
            End: () => this.navigateItem("last"),
          },
        },
      },
    };
  }

  initializeItems() {
    const itemElements = Array.from(
      this.el.querySelectorAll("[data-part='item']"),
    );

    this.items = itemElements.map((element) => {
      // Initialize AccordionItem without hook context
      const itemValue = element.dataset.value;
      element.id = `${this.el.id}-item-${itemValue}`;

      // Check if this item is initially open
      const isOpen = this.collectionManager.getValue(true).includes(itemValue);
      const item = new AccordionItem(element, this, {
        initialState: isOpen ? "open" : "closed",
      });
      this.collectionManager.add(item, item.value);
      return item;
    });
  }

  toggleItem(item) {
    const collectionItem = this.collectionManager.getItemByInstance(item);
    if (!collectionItem) return;

    // Toggle item selection
    this.collectionManager.select(collectionItem);

    // Emit event with current value
    const value = this.collectionManager.getValue();
    this.pushEvent("value-changed", { value });
  }

  navigateItem(direction) {
    const currentFocus = document.activeElement;
    const currentItemElement = currentFocus?.closest("[data-part='item']");
    let currentItem = null;

    if (currentItemElement) {
      currentItem = this.items.find((item) => item.el === currentItemElement);
    }

    let referenceCollectionItem = null;
    if (currentItem) {
      referenceCollectionItem =
        this.collectionManager.getItemByInstance(currentItem);
    }

    // Get the target item using collection manager's navigation methods
    const targetItem = this.collectionManager.getItem(
      direction,
      referenceCollectionItem,
    );

    if (targetItem) {
      this.collectionManager.focus(targetItem);
    }
  }
}

// Register the component
SaladUI.register("accordion", AccordionComponent);

export default AccordionComponent;
