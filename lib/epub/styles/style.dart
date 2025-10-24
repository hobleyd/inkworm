import 'package:xml/xml.dart';

/*
 * This is the abstract base class for the styles; I split CSS styles up into two - BlockStyle for those declarations related to blocks
 * and ElementStyle which relates entirely to text rendering.
 */
abstract class Style {
  Style parseElement(XmlElement element);
}