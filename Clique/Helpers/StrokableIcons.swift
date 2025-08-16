//
//  StrokableIcons.swift
//  Clique
//
//  Created by Kyuho Lee on 1/24/25.
//  Created only for icons that we want outer stroke on.

import SwiftUI

struct ThreeUserIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.67327*width, y: 0.34304*height))
        path.addCurve(to: CGPoint(x: 0.49788*width, y: 0.51944*height), control1: CGPoint(x: 0.67327*width, y: 0.44094*height), control2: CGPoint(x: 0.59521*width, y: 0.51944*height))
        path.addCurve(to: CGPoint(x: 0.32249*width, y: 0.34304*height), control1: CGPoint(x: 0.40054*width, y: 0.51944*height), control2: CGPoint(x: 0.32249*width, y: 0.44094*height))
        path.addCurve(to: CGPoint(x: 0.49788*width, y: 0.16667*height), control1: CGPoint(x: 0.32249*width, y: 0.24509*height), control2: CGPoint(x: 0.40054*width, y: 0.16667*height))
        path.addCurve(to: CGPoint(x: 0.67327*width, y: 0.34304*height), control1: CGPoint(x: 0.59521*width, y: 0.16667*height), control2: CGPoint(x: 0.67327*width, y: 0.24509*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.49788*width, y: 0.83333*height))
        path.addCurve(to: CGPoint(x: 0.23284*width, y: 0.72001*height), control1: CGPoint(x: 0.35491*width, y: 0.83333*height), control2: CGPoint(x: 0.23284*width, y: 0.81067*height))
        path.addCurve(to: CGPoint(x: 0.49788*width, y: 0.60581*height), control1: CGPoint(x: 0.23284*width, y: 0.62931*height), control2: CGPoint(x: 0.35413*width, y: 0.60581*height))
        path.addCurve(to: CGPoint(x: 0.76292*width, y: 0.71918*height), control1: CGPoint(x: 0.64084*width, y: 0.60581*height), control2: CGPoint(x: 0.76292*width, y: 0.62848*height))
        path.addCurve(to: CGPoint(x: 0.49788*width, y: 0.83333*height), control1: CGPoint(x: 0.76292*width, y: 0.80984*height), control2: CGPoint(x: 0.64163*width, y: 0.83333*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.74821*width, y: 0.34622*height))
        path.addCurve(to: CGPoint(x: 0.70721*width, y: 0.48127*height), control1: CGPoint(x: 0.74821*width, y: 0.39613*height), control2: CGPoint(x: 0.73333*width, y: 0.44262*height))
        path.addCurve(to: CGPoint(x: 0.71165*width, y: 0.49144*height), control1: CGPoint(x: 0.70453*width, y: 0.48525*height), control2: CGPoint(x: 0.70691*width, y: 0.49061*height))
        path.addCurve(to: CGPoint(x: 0.73179*width, y: 0.49339*height), control1: CGPoint(x: 0.71818*width, y: 0.49257*height), control2: CGPoint(x: 0.72493*width, y: 0.4932*height))
        path.addCurve(to: CGPoint(x: 0.87868*width, y: 0.38416*height), control1: CGPoint(x: 0.80026*width, y: 0.49519*height), control2: CGPoint(x: 0.86171*width, y: 0.45088*height))
        path.addCurve(to: CGPoint(x: 0.73598*width, y: 0.19608*height), control1: CGPoint(x: 0.90382*width, y: 0.28505*height), control2: CGPoint(x: 0.83*width, y: 0.19608*height))
        path.addCurve(to: CGPoint(x: 0.70647*width, y: 0.19912*height), control1: CGPoint(x: 0.72576*width, y: 0.19608*height), control2: CGPoint(x: 0.71598*width, y: 0.19717*height))
        path.addCurve(to: CGPoint(x: 0.70303*width, y: 0.20118*height), control1: CGPoint(x: 0.70516*width, y: 0.19942*height), control2: CGPoint(x: 0.70378*width, y: 0.20002*height))
        path.addCurve(to: CGPoint(x: 0.70371*width, y: 0.20576*height), control1: CGPoint(x: 0.70213*width, y: 0.20261*height), control2: CGPoint(x: 0.70281*width, y: 0.20452*height))
        path.addCurve(to: CGPoint(x: 0.74821*width, y: 0.34622*height), control1: CGPoint(x: 0.73194*width, y: 0.24557*height), control2: CGPoint(x: 0.74821*width, y: 0.29413*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.86159*width, y: 0.56302*height))
        path.addCurve(to: CGPoint(x: 0.95039*width, y: 0.61736*height), control1: CGPoint(x: 0.9076*width, y: 0.57207*height), control2: CGPoint(x: 0.93785*width, y: 0.59053*height))
        path.addCurve(to: CGPoint(x: 0.95039*width, y: 0.68693*height), control1: CGPoint(x: 0.96098*width, y: 0.63938*height), control2: CGPoint(x: 0.96098*width, y: 0.66494*height))
        path.addCurve(to: CGPoint(x: 0.84536*width, y: 0.74536*height), control1: CGPoint(x: 0.93121*width, y: 0.72854*height), control2: CGPoint(x: 0.86939*width, y: 0.74191*height))
        path.addCurve(to: CGPoint(x: 0.83693*width, y: 0.73681*height), control1: CGPoint(x: 0.8404*width, y: 0.74611*height), control2: CGPoint(x: 0.83641*width, y: 0.74179*height))
        path.addCurve(to: CGPoint(x: 0.72632*width, y: 0.55424*height), control1: CGPoint(x: 0.84921*width, y: 0.62149*height), control2: CGPoint(x: 0.75157*width, y: 0.56681*height))
        path.addCurve(to: CGPoint(x: 0.72512*width, y: 0.55229*height), control1: CGPoint(x: 0.72523*width, y: 0.55368*height), control2: CGPoint(x: 0.72501*width, y: 0.55282*height))
        path.addCurve(to: CGPoint(x: 0.72646*width, y: 0.55121*height), control1: CGPoint(x: 0.7252*width, y: 0.55191*height), control2: CGPoint(x: 0.72564*width, y: 0.55131*height))
        path.addCurve(to: CGPoint(x: 0.86159*width, y: 0.56302*height), control1: CGPoint(x: 0.78112*width, y: 0.55019*height), control2: CGPoint(x: 0.83988*width, y: 0.5577*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.26821*width, y: 0.49339*height))
        path.addCurve(to: CGPoint(x: 0.28836*width, y: 0.49144*height), control1: CGPoint(x: 0.27508*width, y: 0.4932*height), control2: CGPoint(x: 0.28179*width, y: 0.4926*height))
        path.addCurve(to: CGPoint(x: 0.2928*width, y: 0.48127*height), control1: CGPoint(x: 0.2931*width, y: 0.49061*height), control2: CGPoint(x: 0.29549*width, y: 0.48525*height))
        path.addCurve(to: CGPoint(x: 0.2518*width, y: 0.34621*height), control1: CGPoint(x: 0.26668*width, y: 0.44262*height), control2: CGPoint(x: 0.2518*width, y: 0.39612*height))
        path.addCurve(to: CGPoint(x: 0.29631*width, y: 0.20576*height), control1: CGPoint(x: 0.2518*width, y: 0.29413*height), control2: CGPoint(x: 0.26806*width, y: 0.24557*height))
        path.addCurve(to: CGPoint(x: 0.29698*width, y: 0.20118*height), control1: CGPoint(x: 0.2972*width, y: 0.20452*height), control2: CGPoint(x: 0.29784*width, y: 0.2026*height))
        path.addCurve(to: CGPoint(x: 0.29355*width, y: 0.19911*height), control1: CGPoint(x: 0.29623*width, y: 0.20005*height), control2: CGPoint(x: 0.29481*width, y: 0.19941*height))
        path.addCurve(to: CGPoint(x: 0.264*width, y: 0.19607*height), control1: CGPoint(x: 0.28399*width, y: 0.19716*height), control2: CGPoint(x: 0.27422*width, y: 0.19607*height))
        path.addCurve(to: CGPoint(x: 0.12133*width, y: 0.38415*height), control1: CGPoint(x: 0.16998*width, y: 0.19607*height), control2: CGPoint(x: 0.09615*width, y: 0.28505*height))
        path.addCurve(to: CGPoint(x: 0.26821*width, y: 0.49339*height), control1: CGPoint(x: 0.13831*width, y: 0.45087*height), control2: CGPoint(x: 0.19975*width, y: 0.49519*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.27487*width, y: 0.55227*height))
        path.addCurve(to: CGPoint(x: 0.27372*width, y: 0.55426*height), control1: CGPoint(x: 0.27498*width, y: 0.55283*height), control2: CGPoint(x: 0.27476*width, y: 0.55366*height))
        path.addCurve(to: CGPoint(x: 0.16306*width, y: 0.73678*height), control1: CGPoint(x: 0.24842*width, y: 0.56683*height), control2: CGPoint(x: 0.15079*width, y: 0.6215*height))
        path.addCurve(to: CGPoint(x: 0.15466*width, y: 0.74538*height), control1: CGPoint(x: 0.16358*width, y: 0.74181*height), control2: CGPoint(x: 0.15963*width, y: 0.74608*height))
        path.addCurve(to: CGPoint(x: 0.04964*width, y: 0.68694*height), control1: CGPoint(x: 0.13064*width, y: 0.74192*height), control2: CGPoint(x: 0.06882*width, y: 0.72856*height))
        path.addCurve(to: CGPoint(x: 0.04964*width, y: 0.61738*height), control1: CGPoint(x: 0.03901*width, y: 0.66492*height), control2: CGPoint(x: 0.03901*width, y: 0.6394*height))
        path.addCurve(to: CGPoint(x: 0.1384*width, y: 0.563*height), control1: CGPoint(x: 0.06218*width, y: 0.59054*height), control2: CGPoint(x: 0.0924*width, y: 0.57208*height))
        path.addCurve(to: CGPoint(x: 0.27357*width, y: 0.55122*height), control1: CGPoint(x: 0.16015*width, y: 0.55771*height), control2: CGPoint(x: 0.21887*width, y: 0.5502*height))
        path.addCurve(to: CGPoint(x: 0.27487*width, y: 0.55227*height), control1: CGPoint(x: 0.27439*width, y: 0.55133*height), control2: CGPoint(x: 0.2748*width, y: 0.55193*height))
        path.closeSubpath()
        return path
    }
}

struct AddUserIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.39583*width, y: 0.52307*height))
        path.addCurve(to: CGPoint(x: 0.60261*width, y: 0.31362*height), control1: CGPoint(x: 0.5106*width, y: 0.52307*height), control2: CGPoint(x: 0.60261*width, y: 0.42988*height))
        path.addCurve(to: CGPoint(x: 0.39583*width, y: 0.10417*height), control1: CGPoint(x: 0.60261*width, y: 0.19736*height), control2: CGPoint(x: 0.5106*width, y: 0.10417*height))
        path.addCurve(to: CGPoint(x: 0.18906*width, y: 0.31362*height), control1: CGPoint(x: 0.28106*width, y: 0.10417*height), control2: CGPoint(x: 0.18906*width, y: 0.19736*height))
        path.addCurve(to: CGPoint(x: 0.39583*width, y: 0.52307*height), control1: CGPoint(x: 0.18906*width, y: 0.42988*height), control2: CGPoint(x: 0.28106*width, y: 0.52307*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.39583*width, y: 0.62564*height))
        path.addCurve(to: CGPoint(x: 0.08333*width, y: 0.76027*height), control1: CGPoint(x: 0.22726*width, y: 0.62564*height), control2: CGPoint(x: 0.08333*width, y: 0.65258*height))
        path.addCurve(to: CGPoint(x: 0.39583*width, y: 0.89583*height), control1: CGPoint(x: 0.08333*width, y: 0.86791*height), control2: CGPoint(x: 0.22638*width, y: 0.89583*height))
        path.addCurve(to: CGPoint(x: 0.70833*width, y: 0.7612*height), control1: CGPoint(x: 0.56437*width, y: 0.89583*height), control2: CGPoint(x: 0.70833*width, y: 0.86889*height))
        path.addCurve(to: CGPoint(x: 0.39583*width, y: 0.62564*height), control1: CGPoint(x: 0.70833*width, y: 0.65351*height), control2: CGPoint(x: 0.56528*width, y: 0.62564*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.82908*width, y: 0.3995*height))
        path.addLine(to: CGPoint(x: 0.87921*width, y: 0.3995*height))
        path.addCurve(to: CGPoint(x: 0.91667*width, y: 0.43748*height), control1: CGPoint(x: 0.89984*width, y: 0.3995*height), control2: CGPoint(x: 0.91667*width, y: 0.41656*height))
        path.addCurve(to: CGPoint(x: 0.87921*width, y: 0.47546*height), control1: CGPoint(x: 0.91667*width, y: 0.4584*height), control2: CGPoint(x: 0.89984*width, y: 0.47546*height))
        path.addLine(to: CGPoint(x: 0.82908*width, y: 0.47546*height))
        path.addLine(to: CGPoint(x: 0.82908*width, y: 0.52452*height))
        path.addCurve(to: CGPoint(x: 0.79162*width, y: 0.5625*height), control1: CGPoint(x: 0.82908*width, y: 0.54544*height), control2: CGPoint(x: 0.8123*width, y: 0.5625*height))
        path.addCurve(to: CGPoint(x: 0.75416*width, y: 0.52452*height), control1: CGPoint(x: 0.77099*width, y: 0.5625*height), control2: CGPoint(x: 0.75416*width, y: 0.54544*height))
        path.addLine(to: CGPoint(x: 0.75416*width, y: 0.47546*height))
        path.addLine(to: CGPoint(x: 0.70412*width, y: 0.47546*height))
        path.addCurve(to: CGPoint(x: 0.66666*width, y: 0.43748*height), control1: CGPoint(x: 0.68345*width, y: 0.47546*height), control2: CGPoint(x: 0.66666*width, y: 0.4584*height))
        path.addCurve(to: CGPoint(x: 0.70412*width, y: 0.3995*height), control1: CGPoint(x: 0.66666*width, y: 0.41656*height), control2: CGPoint(x: 0.68345*width, y: 0.3995*height))
        path.addLine(to: CGPoint(x: 0.75416*width, y: 0.3995*height))
        path.addLine(to: CGPoint(x: 0.75416*width, y: 0.35049*height))
        path.addCurve(to: CGPoint(x: 0.79162*width, y: 0.3125*height), control1: CGPoint(x: 0.75416*width, y: 0.32956*height), control2: CGPoint(x: 0.77099*width, y: 0.3125*height))
        path.addCurve(to: CGPoint(x: 0.82908*width, y: 0.35049*height), control1: CGPoint(x: 0.8123*width, y: 0.3125*height), control2: CGPoint(x: 0.82908*width, y: 0.32956*height))
        path.addLine(to: CGPoint(x: 0.82908*width, y: 0.3995*height))
        path.closeSubpath()
        return path
    }
}

struct CameraIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.7176*width, y: 0.26946*height))
        path.addCurve(to: CGPoint(x: 0.7256*width, y: 0.27425*height), control1: CGPoint(x: 0.7192*width, y: 0.27225*height), control2: CGPoint(x: 0.722*width, y: 0.27425*height))
        path.addCurve(to: CGPoint(x: 0.9*width, y: 0.44846*height), control1: CGPoint(x: 0.8216*width, y: 0.27425*height), control2: CGPoint(x: 0.9*width, y: 0.35256*height))
        path.addLine(to: CGPoint(x: 0.9*width, y: 0.68579*height))
        path.addCurve(to: CGPoint(x: 0.7256*width, y: 0.86*height), control1: CGPoint(x: 0.9*width, y: 0.78168*height), control2: CGPoint(x: 0.8216*width, y: 0.86*height))
        path.addLine(to: CGPoint(x: 0.2744*width, y: 0.86*height))
        path.addCurve(to: CGPoint(x: 0.1*width, y: 0.68579*height), control1: CGPoint(x: 0.178*width, y: 0.86*height), control2: CGPoint(x: 0.1*width, y: 0.78168*height))
        path.addLine(to: CGPoint(x: 0.1*width, y: 0.44846*height))
        path.addCurve(to: CGPoint(x: 0.2744*width, y: 0.27425*height), control1: CGPoint(x: 0.1*width, y: 0.35256*height), control2: CGPoint(x: 0.178*width, y: 0.27425*height))
        path.addCurve(to: CGPoint(x: 0.282*width, y: 0.26946*height), control1: CGPoint(x: 0.2776*width, y: 0.27425*height), control2: CGPoint(x: 0.2808*width, y: 0.27265*height))
        path.addLine(to: CGPoint(x: 0.2844*width, y: 0.26466*height))
        path.addCurve(to: CGPoint(x: 0.28863*width, y: 0.25575*height), control1: CGPoint(x: 0.28578*width, y: 0.26176*height), control2: CGPoint(x: 0.28719*width, y: 0.25878*height))
        path.addCurve(to: CGPoint(x: 0.3172*width, y: 0.19634*height), control1: CGPoint(x: 0.29886*width, y: 0.2342*height), control2: CGPoint(x: 0.31019*width, y: 0.21035*height))
        path.addCurve(to: CGPoint(x: 0.4056*width, y: 0.14*height), control1: CGPoint(x: 0.3356*width, y: 0.16038*height), control2: CGPoint(x: 0.3668*width, y: 0.1404*height))
        path.addLine(to: CGPoint(x: 0.594*width, y: 0.14*height))
        path.addCurve(to: CGPoint(x: 0.6828*width, y: 0.19634*height), control1: CGPoint(x: 0.6328*width, y: 0.1404*height), control2: CGPoint(x: 0.6644*width, y: 0.16038*height))
        path.addCurve(to: CGPoint(x: 0.70795*width, y: 0.24874*height), control1: CGPoint(x: 0.6891*width, y: 0.20892*height), control2: CGPoint(x: 0.6987*width, y: 0.2292*height))
        path.addCurve(to: CGPoint(x: 0.7136*width, y: 0.26067*height), control1: CGPoint(x: 0.70986*width, y: 0.25277*height), control2: CGPoint(x: 0.71175*width, y: 0.25677*height))
        path.addLine(to: CGPoint(x: 0.7176*width, y: 0.26946*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.6884*width, y: 0.42289*height))
        path.addCurve(to: CGPoint(x: 0.7244*width, y: 0.45885*height), control1: CGPoint(x: 0.6884*width, y: 0.44287*height), control2: CGPoint(x: 0.7044*width, y: 0.45885*height))
        path.addCurve(to: CGPoint(x: 0.7608*width, y: 0.42289*height), control1: CGPoint(x: 0.7444*width, y: 0.45885*height), control2: CGPoint(x: 0.7608*width, y: 0.44287*height))
        path.addCurve(to: CGPoint(x: 0.7244*width, y: 0.38653*height), control1: CGPoint(x: 0.7608*width, y: 0.40291*height), control2: CGPoint(x: 0.7444*width, y: 0.38653*height))
        path.addCurve(to: CGPoint(x: 0.6884*width, y: 0.42289*height), control1: CGPoint(x: 0.7044*width, y: 0.38653*height), control2: CGPoint(x: 0.6884*width, y: 0.40291*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.4308*width, y: 0.48482*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.45605*height), control1: CGPoint(x: 0.4496*width, y: 0.46604*height), control2: CGPoint(x: 0.474*width, y: 0.45605*height))
        path.addCurve(to: CGPoint(x: 0.5688*width, y: 0.48442*height), control1: CGPoint(x: 0.526*width, y: 0.45605*height), control2: CGPoint(x: 0.5504*width, y: 0.46604*height))
        path.addCurve(to: CGPoint(x: 0.5972*width, y: 0.55314*height), control1: CGPoint(x: 0.5872*width, y: 0.50279*height), control2: CGPoint(x: 0.5972*width, y: 0.52717*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.65024*height), control1: CGPoint(x: 0.5968*width, y: 0.60668*height), control2: CGPoint(x: 0.5536*width, y: 0.65024*height))
        path.addCurve(to: CGPoint(x: 0.4312*width, y: 0.62187*height), control1: CGPoint(x: 0.474*width, y: 0.65024*height), control2: CGPoint(x: 0.4496*width, y: 0.64024*height))
        path.addCurve(to: CGPoint(x: 0.4028*width, y: 0.55314*height), control1: CGPoint(x: 0.4128*width, y: 0.60348*height), control2: CGPoint(x: 0.4028*width, y: 0.57911*height))
        path.addLine(to: CGPoint(x: 0.4028*width, y: 0.55274*height))
        path.addCurve(to: CGPoint(x: 0.4308*width, y: 0.48482*height), control1: CGPoint(x: 0.4024*width, y: 0.52757*height), control2: CGPoint(x: 0.4124*width, y: 0.5032*height))
        path.closeSubpath()
        path.move(to: CGPoint(x: 0.6108*width, y: 0.66421*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.71017*height), control1: CGPoint(x: 0.5824*width, y: 0.69259*height), control2: CGPoint(x: 0.5432*width, y: 0.71017*height))
        path.addCurve(to: CGPoint(x: 0.3888*width, y: 0.66421*height), control1: CGPoint(x: 0.458*width, y: 0.71017*height), control2: CGPoint(x: 0.4188*width, y: 0.69378*height))
        path.addCurve(to: CGPoint(x: 0.3428*width, y: 0.55314*height), control1: CGPoint(x: 0.3592*width, y: 0.63425*height), control2: CGPoint(x: 0.3428*width, y: 0.59509*height))
        path.addCurve(to: CGPoint(x: 0.3884*width, y: 0.44246*height), control1: CGPoint(x: 0.3424*width, y: 0.51158*height), control2: CGPoint(x: 0.3588*width, y: 0.47243*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.39611*height), control1: CGPoint(x: 0.4184*width, y: 0.4125*height), control2: CGPoint(x: 0.458*width, y: 0.39611*height))
        path.addCurve(to: CGPoint(x: 0.6112*width, y: 0.44206*height), control1: CGPoint(x: 0.542*width, y: 0.39611*height), control2: CGPoint(x: 0.5816*width, y: 0.4125*height))
        path.addCurve(to: CGPoint(x: 0.6572*width, y: 0.55314*height), control1: CGPoint(x: 0.6408*width, y: 0.47203*height), control2: CGPoint(x: 0.6572*width, y: 0.51158*height))
        path.addCurve(to: CGPoint(x: 0.6108*width, y: 0.66421*height), control1: CGPoint(x: 0.6568*width, y: 0.59669*height), control2: CGPoint(x: 0.6392*width, y: 0.63584*height))
        path.closeSubpath()
        return path
    }
}

struct CrownLeaderIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.76042*width, y: 0.76666*height))
        path.addLine(to: CGPoint(x: 0.23955*width, y: 0.76666*height))
        path.addCurve(to: CGPoint(x: 0.18463*width, y: 0.74839*height), control1: CGPoint(x: 0.21936*width, y: 0.76672*height), control2: CGPoint(x: 0.19984*width, y: 0.76021*height))
        path.addCurve(to: CGPoint(x: 0.15689*width, y: 0.70237*height), control1: CGPoint(x: 0.16942*width, y: 0.73655*height), control2: CGPoint(x: 0.15956*width, y: 0.7202*height))
        path.addLine(to: CGPoint(x: 0.10046*width, y: 0.33127*height))
        path.addCurve(to: CGPoint(x: 0.10562*width, y: 0.30472*height), control1: CGPoint(x: 0.09906*width, y: 0.32216*height), control2: CGPoint(x: 0.10086*width, y: 0.31288*height))
        path.addCurve(to: CGPoint(x: 0.12703*width, y: 0.28569*height), control1: CGPoint(x: 0.11038*width, y: 0.29656*height), control2: CGPoint(x: 0.11785*width, y: 0.28991*height))
        path.addCurve(to: CGPoint(x: 0.15683*width, y: 0.28115*height), control1: CGPoint(x: 0.1362*width, y: 0.28147*height), control2: CGPoint(x: 0.14661*width, y: 0.27989*height))
        path.addCurve(to: CGPoint(x: 0.18411*width, y: 0.29278*height), control1: CGPoint(x: 0.16705*width, y: 0.28242*height), control2: CGPoint(x: 0.17658*width, y: 0.28648*height))
        path.addLine(to: CGPoint(x: 0.27725*width, y: 0.36953*height))
        path.addCurve(to: CGPoint(x: 0.29443*width, y: 0.37921*height), control1: CGPoint(x: 0.28217*width, y: 0.37377*height), control2: CGPoint(x: 0.28802*width, y: 0.37707*height))
        path.addCurve(to: CGPoint(x: 0.31452*width, y: 0.38198*height), control1: CGPoint(x: 0.30084*width, y: 0.38135*height), control2: CGPoint(x: 0.30768*width, y: 0.38229*height))
        path.addCurve(to: CGPoint(x: 0.33418*width, y: 0.37739*height), control1: CGPoint(x: 0.32136*width, y: 0.38166*height), control2: CGPoint(x: 0.32805*width, y: 0.3801*height))
        path.addCurve(to: CGPoint(x: 0.35016*width, y: 0.3662*height), control1: CGPoint(x: 0.34031*width, y: 0.37467*height), control2: CGPoint(x: 0.34575*width, y: 0.37086*height))
        path.addLine(to: CGPoint(x: 0.46153*width, y: 0.24917*height))
        path.addCurve(to: CGPoint(x: 0.47866*width, y: 0.23749*height), control1: CGPoint(x: 0.46622*width, y: 0.24421*height), control2: CGPoint(x: 0.47206*width, y: 0.24022*height))
        path.addCurve(to: CGPoint(x: 0.49973*width, y: 0.23333*height), control1: CGPoint(x: 0.48526*width, y: 0.23475*height), control2: CGPoint(x: 0.49245*width, y: 0.23333*height))
        path.addCurve(to: CGPoint(x: 0.5208*width, y: 0.23749*height), control1: CGPoint(x: 0.50701*width, y: 0.23333*height), control2: CGPoint(x: 0.5142*width, y: 0.23475*height))
        path.addCurve(to: CGPoint(x: 0.53793*width, y: 0.24917*height), control1: CGPoint(x: 0.5274*width, y: 0.24022*height), control2: CGPoint(x: 0.53325*width, y: 0.24421*height))
        path.addLine(to: CGPoint(x: 0.6498*width, y: 0.3662*height))
        path.addCurve(to: CGPoint(x: 0.66558*width, y: 0.37724*height), control1: CGPoint(x: 0.65417*width, y: 0.37079*height), control2: CGPoint(x: 0.65954*width, y: 0.37455*height))
        path.addCurve(to: CGPoint(x: 0.68498*width, y: 0.38185*height), control1: CGPoint(x: 0.67163*width, y: 0.37993*height), control2: CGPoint(x: 0.67823*width, y: 0.3815*height))
        path.addCurve(to: CGPoint(x: 0.70483*width, y: 0.3793*height), control1: CGPoint(x: 0.69172*width, y: 0.38221*height), control2: CGPoint(x: 0.69848*width, y: 0.38134*height))
        path.addCurve(to: CGPoint(x: 0.72196*width, y: 0.36998*height), control1: CGPoint(x: 0.7112*width, y: 0.37726*height), control2: CGPoint(x: 0.71703*width, y: 0.37409*height))
        path.addLine(to: CGPoint(x: 0.8151*width, y: 0.29322*height))
        path.addCurve(to: CGPoint(x: 0.84243*width, y: 0.28103*height), control1: CGPoint(x: 0.82256*width, y: 0.28671*height), control2: CGPoint(x: 0.83211*width, y: 0.28245*height))
        path.addCurve(to: CGPoint(x: 0.87261*width, y: 0.2853*height), control1: CGPoint(x: 0.85274*width, y: 0.27961*height), control2: CGPoint(x: 0.86329*width, y: 0.2811*height))
        path.addCurve(to: CGPoint(x: 0.89435*width, y: 0.30443*height), control1: CGPoint(x: 0.88192*width, y: 0.28949*height), control2: CGPoint(x: 0.88952*width, y: 0.29619*height))
        path.addCurve(to: CGPoint(x: 0.8995*width, y: 0.33127*height), control1: CGPoint(x: 0.89917*width, y: 0.31268*height), control2: CGPoint(x: 0.90097*width, y: 0.32206*height))
        path.addLine(to: CGPoint(x: 0.84307*width, y: 0.70215*height))
        path.addCurve(to: CGPoint(x: 0.81541*width, y: 0.7483*height), control1: CGPoint(x: 0.84046*width, y: 0.72001*height), control2: CGPoint(x: 0.83063*width, y: 0.73642*height))
        path.addCurve(to: CGPoint(x: 0.76042*width, y: 0.76666*height), control1: CGPoint(x: 0.8002*width, y: 0.76018*height), control2: CGPoint(x: 0.78065*width, y: 0.7667*height))
        path.closeSubpath()
        return path
    }
}

struct HeartFilledIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.74042*width, y: 0.11222*height))
        path.addCurve(to: CGPoint(x: 0.66211*width, y: 0.10001*height), control1: CGPoint(x: 0.7152*width, y: 0.10375*height), control2: CGPoint(x: 0.68867*width, y: 0.10001*height))
        path.addCurve(to: CGPoint(x: 0.5*width, y: 0.1547*height), control1: CGPoint(x: 0.60357*width, y: 0.09959*height), control2: CGPoint(x: 0.54678*width, y: 0.11895*height))
        path.addCurve(to: CGPoint(x: 0.48737*width, y: 0.14674*height), control1: CGPoint(x: 0.49621*width, y: 0.1518*height), control2: CGPoint(x: 0.49158*width, y: 0.14923*height))
        path.addCurve(to: CGPoint(x: 0.46926*width, y: 0.13453*height), control1: CGPoint(x: 0.48316*width, y: 0.14417*height), control2: CGPoint(x: 0.47558*width, y: 0.1379*height))
        path.addLine(to: CGPoint(x: 0.45326*width, y: 0.12737*height))
        path.addCurve(to: CGPoint(x: 0.42674*width, y: 0.11639*height), control1: CGPoint(x: 0.44484*width, y: 0.12274*height), control2: CGPoint(x: 0.43604*width, y: 0.11938*height))
        path.addCurve(to: CGPoint(x: 0.42295*width, y: 0.1139*height), control1: CGPoint(x: 0.42589*width, y: 0.11559*height), control2: CGPoint(x: 0.42463*width, y: 0.1147*height))
        path.addLine(to: CGPoint(x: 0.42046*width, y: 0.1139*height))
        path.addCurve(to: CGPoint(x: 0.34337*width, y: 0.10001*height), control1: CGPoint(x: 0.39558*width, y: 0.10544*height), control2: CGPoint(x: 0.36989*width, y: 0.10081*height))
        path.addLine(to: CGPoint(x: 0.33874*width, y: 0.10001*height))
        path.addCurve(to: CGPoint(x: 0.30337*width, y: 0.10253*height), control1: CGPoint(x: 0.32695*width, y: 0.10001*height), control2: CGPoint(x: 0.3152*width, y: 0.10081*height))
        path.addLine(to: CGPoint(x: 0.29832*width, y: 0.10253*height))
        path.addCurve(to: CGPoint(x: 0.26088*width, y: 0.11133*height), control1: CGPoint(x: 0.28569*width, y: 0.10417*height), control2: CGPoint(x: 0.2731*width, y: 0.10712*height))
        path.addCurve(to: CGPoint(x: 0.09537*width, y: 0.48232*height), control1: CGPoint(x: 0.10379*width, y: 0.16274*height), control2: CGPoint(x: 0.04779*width, y: 0.33327*height))
        path.addCurve(to: CGPoint(x: 0.22215*width, y: 0.68438*height), control1: CGPoint(x: 0.12232*width, y: 0.55849*height), control2: CGPoint(x: 0.16573*width, y: 0.62758*height))
        path.addCurve(to: CGPoint(x: 0.49031*width, y: 0.89322*height), control1: CGPoint(x: 0.30421*width, y: 0.76354*height), control2: CGPoint(x: 0.39394*width, y: 0.83343*height))
        path.addLine(to: CGPoint(x: 0.50126*width, y: 0.9*height))
        path.addLine(to: CGPoint(x: 0.51179*width, y: 0.89364*height))
        path.addCurve(to: CGPoint(x: 0.77836*width, y: 0.6848*height), control1: CGPoint(x: 0.60783*width, y: 0.83343*height), control2: CGPoint(x: 0.69705*width, y: 0.76354*height))
        path.addCurve(to: CGPoint(x: 0.90505*width, y: 0.48232*height), control1: CGPoint(x: 0.83515*width, y: 0.628*height), control2: CGPoint(x: 0.87852*width, y: 0.55849*height))
        path.addCurve(to: CGPoint(x: 0.74042*width, y: 0.11222*height), control1: CGPoint(x: 0.95183*width, y: 0.33327*height), control2: CGPoint(x: 0.89582*width, y: 0.16274*height))
        path.closeSubpath()
        return path
    }
}

struct CommentFilledIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        path.move(to: CGPoint(x: 0.78285*width, y: 0.7828*height))
        path.addCurve(to: CGPoint(x: 0.33146*width, y: 0.86296*height), control1: CGPoint(x: 0.66061*width, y: 0.90505*height), control2: CGPoint(x: 0.47959*width, y: 0.93147*height))
        path.addCurve(to: CGPoint(x: 0.27461*width, y: 0.84704*height), control1: CGPoint(x: 0.30959*width, y: 0.85416*height), control2: CGPoint(x: 0.29166*width, y: 0.84704*height))
        path.addCurve(to: CGPoint(x: 0.13733*width, y: 0.86268*height), control1: CGPoint(x: 0.22714*width, y: 0.84732*height), control2: CGPoint(x: 0.16805*width, y: 0.89336*height))
        path.addCurve(to: CGPoint(x: 0.15269*width, y: 0.72506*height), control1: CGPoint(x: 0.10662*width, y: 0.83196*height), control2: CGPoint(x: 0.15269*width, y: 0.77282*height))
        path.addCurve(to: CGPoint(x: 0.13705*width, y: 0.66849*height), control1: CGPoint(x: 0.15269*width, y: 0.70801*height), control2: CGPoint(x: 0.14586*width, y: 0.6904*height))
        path.addCurve(to: CGPoint(x: 0.21721*width, y: 0.21709*height), control1: CGPoint(x: 0.06851*width, y: 0.52038*height), control2: CGPoint(x: 0.09496*width, y: 0.33931*height))
        path.addCurve(to: CGPoint(x: 0.78285*width, y: 0.21705*height), control1: CGPoint(x: 0.37326*width, y: 0.06098*height), control2: CGPoint(x: 0.6268*width, y: 0.06098*height))
        path.addCurve(to: CGPoint(x: 0.78285*width, y: 0.7828*height), control1: CGPoint(x: 0.93919*width, y: 0.3734*height), control2: CGPoint(x: 0.93891*width, y: 0.62672*height))
        path.closeSubpath()
        return path
    }
}
