import {
  HiArchiveBox, HiSparkles, HiCircleStack, HiFire,
  HiUserCircle, HiHeart, HiWrenchScrewdriver, HiSquares2X2, HiSun, HiCake,
} from "react-icons/hi2";
import { MdLocalDrink, MdAcUnit, MdBakeryDining, MdCleaningServices, MdChildCare, MdPets } from "react-icons/md";
import { RiLeafFill } from "react-icons/ri";

const ICON_MAP = {
  HiArchiveBox,
  HiSparkles,
  HiCircleStack,
  HiFire,
  HiSun,
  HiCake,
  HiUserCircle,
  HiHeart,
  HiWrenchScrewdriver,
  HiSquares2X2,
  MdLocalDrink,
  MdAcUnit,
  MdBakeryDining,
  MdCleaningServices,
  MdChildCare,
  MdPets,
  RiLeafFill,
};

// Fallback when a category has no icon or an unknown icon name
const DEFAULT_ICON = HiSquares2X2;

export function getIconComponent(iconName) {
  return ICON_MAP[iconName] ?? DEFAULT_ICON;
}
