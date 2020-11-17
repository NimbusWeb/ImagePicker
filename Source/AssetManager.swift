import Foundation
import UIKit
import Photos

extension Bundle {
    static func myResourceBundle() -> Bundle? {
        let bundles = Bundle.allBundles
        let bundlePaths = bundles.compactMap { $0.resourceURL?.appendingPathComponent("ImagePicker", isDirectory: false).appendingPathExtension("bundle") }

        return bundlePaths.compactMap({ Bundle(url: $0) }).first
    }
}

open class AssetManager {

  public static func getImage(_ name: String) -> UIImage {
    let traitCollection = UITraitCollection(displayScale: 3)
    var bundle = Bundle.myResourceBundle()

    if let resource = bundle?.resourcePath, let resourceBundle = Bundle(path: resource + "/ImagePicker.bundle") {
      bundle = resourceBundle
    }

    return UIImage(named: name, in: bundle, compatibleWith: traitCollection) ?? UIImage()
  }

  public static func fetch(withConfiguration configuration: ImagePickerConfiguration, _ completion: @escaping (_ assets: [PHAsset]) -> Void) {
    guard PHPhotoLibrary.authorizationStatus() == .authorized else { return }

    DispatchQueue.global(qos: .background).async {
      let fetchResult = configuration.allowVideoSelection
        ? PHAsset.fetchAssets(with: PHFetchOptions())
        : PHAsset.fetchAssets(with: .image, options: PHFetchOptions())

      if fetchResult.count > 0 {
        var assets = [PHAsset]()
        fetchResult.enumerateObjects({ object, _, _ in
          assets.insert(object, at: 0)
        })

        DispatchQueue.main.async {
          completion(assets)
        }
      }
    }
  }

  public static func resolveAsset(_ asset: PHAsset, size: CGSize = CGSize(width: 720, height: 1280), shouldPreferLowRes: Bool = false, completion: @escaping (_ image: UIImage?) -> Void) {
    let imageManager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    requestOptions.deliveryMode = shouldPreferLowRes ? .fastFormat : .highQualityFormat
    requestOptions.isNetworkAccessAllowed = true

    imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, info in
      if let info = info, info["PHImageFileUTIKey"] == nil {
        DispatchQueue.main.async(execute: {
          completion(image)
        })
      }
    }
  }

  public static func resolveAssets(_ assets: [PHAsset], size: CGSize = CGSize(width: 720, height: 1280)) -> [UIImage] {
    let imageManager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    requestOptions.isSynchronous = true

    var images = [UIImage]()
    for asset in assets {
      imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, _ in
        if let image = image {
          images.append(image)
        }
      }
    }
    return images
  }

  public static func resolveNamedAssets(_ assets: [PHAsset], size: CGSize = CGSize(width: 720, height: 1280)) -> [NamedImage] {
    let imageManager = PHImageManager.default()
    let requestOptions = PHImageRequestOptions()
    requestOptions.isSynchronous = true

    var images = [NamedImage]()
    for asset in assets {
      imageManager.requestImage(for: asset, targetSize: size, contentMode: .aspectFill, options: requestOptions) { image, _ in
        if let image = image {
          let name = (asset.value(forKey: "filename") as? String)?.fileName
          images.append(NamedImage(image: image, name: name))
        }
      }
    }
    return images
  }
}

public class NamedImage: NSObject {
  public let name: String?
  public let image: UIImage
  init(image: UIImage, name: String?) {
    self.image = image
    self.name = name
  }
}

extension String {
  var fileName: String {
    var components = self.components(separatedBy: ".")
    if components.count > 1 {
      components.removeLast()
      return components.joined(separator: ".")
    } else {
      return self
    }
  }
}
